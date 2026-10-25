//
//  MetalScreenView.swift
//  speccyMac
//
//  Renders the emulator frame on the GPU (Level 2). The CPU no longer builds
//  an RGBA bitmap: each frame it uploads the raw Spectrum screen bytes,
//  attribute bytes, a per-output-row border colour index, and a flash flag.
//  The fragment shader expands these into pixels — resolving ink/paper,
//  bright, and flash — using a 16-entry palette, and fills the border.
//

import Cocoa
import Metal
import MetalKit

/// Receives game-file drops from the Metal view.
protocol DragDelegate: AnyObject {
    func loadGame(_ fileUrl: URL)
}

final class MetalScreenView: MTKView {

    // Output frame size (screen + border).
    private let frameWidth  = 320
    private let frameHeight = 288

    // Spectrum display is 256x192 = 32x192 cells (one screen/attribute byte per
    // 8-pixel cell, one attribute row per pixel row to allow hi-colour effects).
    private let cellsWide = 32
    private let cellRows  = 192

    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!

    // Raw Spectrum data, uploaded each frame.
    private var screenTexture: MTLTexture!   // R8Uint, 32x192 screen bytes
    private var attrTexture:   MTLTexture!   // R8Uint, 32x192 attribute bytes

    // Per-output-row border colour index (0..7), uploaded each frame.
    private var borderBufferGPU: MTLBuffer!

    // 16-entry RGBA palette, uploaded once.
    private var paletteBuffer: MTLBuffer!

    // Per-frame uniforms (flash flag + display-mode flags + scale).
    private var uniformBuffer: MTLBuffer!

    /// Mutually-exclusive display modes selectable from the UI.
    enum DisplayMode: Int, CaseIterable, Identifiable {
        case crisp = 0
        case smooth = 1
        case scanlines = 2
        case crt = 3

        var id: Int { rawValue }

        /// Human-readable name for menus/pickers.
        var title: String {
            switch self {
            case .crisp:     return "Crisp"
            case .smooth:    return "Smooth"
            case .scanlines: return "Scanlines"
            case .crt:       return "CRT"
            }
        }
    }
    private var displayMode: DisplayMode = .crisp

    // Latest flash-invert state from the emulator (written into uniforms at draw time).
    private var lastInvertFlash = false

    weak var dragDelegate: DragDelegate?

    // Matches the Uniforms struct in the shader.
    private struct Uniforms {
        var invertFlash: UInt32
        var smoothing: UInt32
        var scanlines: UInt32
        var crt: UInt32
        var scaleY: Float
    }

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        if device == nil {
            device = MTLCreateSystemDefaultDevice()
        }
        commonInit()
    }

    private func commonInit() {
        guard let device = device else {
            fatalError("Metal is not supported on this device")
        }

        // The emulator pushes frames at its own cadence, so draw on demand
        // rather than on a continuous timer.
        isPaused = true
        enableSetNeedsDisplay = true
        framebufferOnly = true
        colorPixelFormat = .bgra8Unorm
        // Letterbox the Spectrum image against a black surround.
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        layer?.magnificationFilter = .nearest

        commandQueue = device.makeCommandQueue()

        buildPipeline(device: device)
        buildTextures(device: device)
        buildBuffers(device: device)

        registerForDraggedTypes([.fileURL])
    }

    // MARK: - Metal setup

    private func buildPipeline(device: MTLDevice) {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;   // 0..1 across the output frame
        };

        struct Uniforms {
            uint invertFlash;
            uint smoothing;
            uint scanlines;
            uint crt;
            float scaleY;
        };

        // Fullscreen quad generated from the vertex id (no vertex buffer).
        vertex VertexOut screen_vertex(uint vid [[vertex_id]]) {
            float2 positions[4] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };
            // Flip V so row 0 is at the top of the view.
            float2 coords[4] = {
                float2(0.0, 1.0),
                float2(1.0, 1.0),
                float2(0.0, 0.0),
                float2(1.0, 0.0)
            };

            VertexOut out;
            out.position = float4(positions[vid], 0.0, 1.0);
            out.texCoord = coords[vid];
            return out;
        }

        // Frame / border geometry (must match Spectrum's layout).
        constant uint kFrameWidth    = 320u;
        constant uint kFrameHeight   = 288u;
        constant uint kBorderLeft    = 32u;
        constant uint kBorderTop     = 48u;
        constant uint kScreenWidth   = 256u;
        constant uint kScreenHeight  = 192u;

        // Resolve the RGBA colour of a single logical frame pixel (px, py).
        // Handles both the border and the 256x192 screen area.
        static float4 colourAt(uint px, uint py,
                               texture2d<uint> screenTex,
                               texture2d<uint> attrTex,
                               constant float4 *palette,
                               constant uchar  *borderLine,
                               uint invertFlash) {

            bool inScreenX = (px >= kBorderLeft) && (px < kBorderLeft + kScreenWidth);
            bool inScreenY = (py >= kBorderTop)  && (py < kBorderTop + kScreenHeight);

            if (!(inScreenX && inScreenY)) {
                uint idx = uint(borderLine[py]) & 0x07u;
                return palette[idx];
            }

            uint sx = px - kBorderLeft;
            uint sy = py - kBorderTop;

            uint col = sx >> 3;          // 0..31  (cell column)
            uint bit = sx & 7u;          // 0..7   (MSB first)
            uint row = sy;               // 0..191 (attribute stored per row)

            uint byte = screenTex.read(uint2(col, row)).r;
            uint attr = attrTex.read(uint2(col, row)).r;

            uint bright = (attr & 0x40u) != 0u ? 8u : 0u;
            uint inkIdx   = (attr & 0x07u) + bright;
            uint paperIdx = ((attr & 0x38u) >> 3) + bright;

            if (invertFlash != 0u && (attr & 0x80u) != 0u) {
                uint t = inkIdx; inkIdx = paperIdx; paperIdx = t;
            }

            bool pixelSet = (byte & (0x80u >> bit)) != 0u;
            return pixelSet ? palette[inkIdx] : palette[paperIdx];
        }

        fragment float4 screen_fragment(VertexOut in [[stage_in]],
                                        texture2d<uint> screenTex [[texture(0)]],
                                        texture2d<uint> attrTex   [[texture(1)]],
                                        constant float4 *palette   [[buffer(0)]],
                                        constant uchar  *borderLine [[buffer(1)]],
                                        constant Uniforms &uniforms [[buffer(2)]]) {

            bool crt = (uniforms.crt != 0u);

            // Sample coordinate in 0..1 across the frame. In CRT mode we apply
            // barrel distortion so the image bulges like a real tube.
            float2 uv = in.texCoord;
            if (crt) {
                float2 c = uv * 2.0 - 1.0;          // -1..1 centred
                float r2 = dot(c, c);
                float k = 0.08;                     // curvature strength
                c *= 1.0 + k * r2;                  // push corners outward
                uv = c * 0.5 + 0.5;
                // Outside the tube after warping -> black bezel.
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
                    return float4(0.0, 0.0, 0.0, 1.0);
                }
            }

            // Continuous position in frame space (pixel centres at integer+0.5).
            float fx = uv.x * float(kFrameWidth);
            float fy = uv.y * float(kFrameHeight);

            float4 colour;
            if (uniforms.smoothing == 0u) {
                // Crisp: point-sample the covering pixel.
                uint px = min(uint(fx), kFrameWidth  - 1u);
                uint py = min(uint(fy), kFrameHeight - 1u);
                colour = colourAt(px, py, screenTex, attrTex, palette, borderLine,
                                  uniforms.invertFlash);
            } else {
                // Smooth: bilinear blend of the four pixel centres around (fx, fy).
                float gx = fx - 0.5;
                float gy = fy - 0.5;
                float x0f = floor(gx);
                float y0f = floor(gy);
                float wx = gx - x0f;
                float wy = gy - y0f;

                uint x0 = uint(clamp(x0f, 0.0, float(kFrameWidth  - 1u)));
                uint y0 = uint(clamp(y0f, 0.0, float(kFrameHeight - 1u)));
                uint x1 = min(x0 + 1u, kFrameWidth  - 1u);
                uint y1 = min(y0 + 1u, kFrameHeight - 1u);

                float4 c00 = colourAt(x0, y0, screenTex, attrTex, palette, borderLine, uniforms.invertFlash);
                float4 c10 = colourAt(x1, y0, screenTex, attrTex, palette, borderLine, uniforms.invertFlash);
                float4 c01 = colourAt(x0, y1, screenTex, attrTex, palette, borderLine, uniforms.invertFlash);
                float4 c11 = colourAt(x1, y1, screenTex, attrTex, palette, borderLine, uniforms.invertFlash);

                float4 top = mix(c00, c10, wx);
                float4 bot = mix(c01, c11, wx);
                colour = mix(top, bot, wy);
            }

            // Scanline modulation: darken toward the gaps between source rows.
            // Only meaningful when the image is upscaled, so fade the effect out
            // at small scale factors to avoid aliasing. Active for Scanlines and CRT.
            if (uniforms.scanlines != 0u || crt) {
                float scaleY = uniforms.scaleY;             // output px per source row
                float strength = clamp((scaleY - 2.0) / 2.0, 0.0, 1.0);
                float frac = fract(fy);                     // 0..1 within source row
                float dist = abs(frac - 0.5) * 2.0;         // 0 centre, 1 at edges
                float depth = 0.45 * strength;              // max darkening
                float scan = 1.0 - depth * dist;
                colour.rgb *= scan;
            }

            if (crt) {
                // Aperture-grille shadow mask: cycle R/G/B emphasis across
                // columns of output pixels so phosphor triads are suggested.
                // in.position.x is the output pixel coordinate.
                uint col = uint(in.position.x) % 3u;
                float3 mask = float3(1.0);
                float dim = 0.85;                   // non-emphasised channel level
                if (col == 0u)      mask = float3(1.0, dim, dim);
                else if (col == 1u) mask = float3(dim, 1.0, dim);
                else                mask = float3(dim, dim, 1.0);
                colour.rgb *= mask;

                // Vignette: gently darken toward the edges/corners of the tube.
                float2 c = uv * 2.0 - 1.0;
                float vig = 1.0 - 0.25 * dot(c, c);
                colour.rgb *= clamp(vig, 0.0, 1.0);
            }

            return colour;
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "screen_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "screen_fragment")
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to build Metal pipeline: \(error)")
        }
    }

    private func buildTextures(device: MTLDevice) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Uint,
            width: cellsWide,
            height: cellRows,
            mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .managed
        screenTexture = device.makeTexture(descriptor: descriptor)
        attrTexture   = device.makeTexture(descriptor: descriptor)
    }

    private func buildBuffers(device: MTLDevice) {
        borderBufferGPU = device.makeBuffer(length: frameHeight, options: .storageModeManaged)
        uniformBuffer   = device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                            options: .storageModeManaged)
    }

    /// Supply the 16-entry palette as packed 0x00RRGGBB values (as Spectrum
    /// stores them). Converted to normalised float4 and uploaded once.
    func setPalette(_ colours: UnsafePointer<UInt32>) {
        var rgba = [SIMD4<Float>](repeating: .zero, count: 16)
        for i in 0..<16 {
            let word = colours[i]
            // Spectrum packs r<<8, g<<16, b<<24 (low byte is alpha 0xff).
            let r = Float((word >> 8)  & 0xff) / 255.0
            let g = Float((word >> 16) & 0xff) / 255.0
            let b = Float((word >> 24) & 0xff) / 255.0
            rgba[i] = SIMD4<Float>(r, g, b, 1.0)
        }
        let length = MemoryLayout<SIMD4<Float>>.stride * 16
        paletteBuffer = device?.makeBuffer(bytes: &rgba, length: length,
                                           options: .storageModeManaged)
    }

    // MARK: - Public API

    /// Select the display mode (crisp / smooth / scanlines). All three are
    /// implemented in the fragment shader; the choice is passed via uniforms.
    func setDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
        setNeedsDisplay(bounds)
    }

    /// Upload raw Spectrum frame data and request a redraw.
    /// - screen: 32*192 screen bytes (one per 8-pixel cell).
    /// - attributes: 32*192 attribute bytes (one per pixel row).
    /// - borderLines: `frameHeight` border colour indices, one per output row.
    /// - invertFlash: whether flashing cells currently have ink/paper swapped.
    func updateFrame(screen: UnsafePointer<UInt8>,
                     attributes: UnsafePointer<UInt8>,
                     borderLines: UnsafePointer<UInt8>,
                     invertFlash: Bool) {

        let region = MTLRegionMake2D(0, 0, cellsWide, cellRows)
        screenTexture.replace(region: region, mipmapLevel: 0,
                              withBytes: screen, bytesPerRow: cellsWide)
        attrTexture.replace(region: region, mipmapLevel: 0,
                            withBytes: attributes, bytesPerRow: cellsWide)

        memcpy(borderBufferGPU.contents(), borderLines, frameHeight)
        borderBufferGPU.didModifyRange(0..<frameHeight)

        // Uniforms (including display-mode flags and scale) are written in
        // draw(), where the viewport scale is known. Just record the flash state.
        lastInvertFlash = invertFlash

        setNeedsDisplay(bounds)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let paletteBuffer = paletteBuffer,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        // Compute an aspect-fit viewport so the frame letterboxes inside the view.
        let drawableSize = self.drawableSize
        let targetAspect = CGFloat(frameWidth) / CGFloat(frameHeight)
        let viewAspect = drawableSize.width / drawableSize.height

        var vpWidth = drawableSize.width
        var vpHeight = drawableSize.height
        if viewAspect > targetAspect {
            vpWidth = drawableSize.height * targetAspect
        } else {
            vpHeight = drawableSize.width / targetAspect
        }
        let originX = (drawableSize.width - vpWidth) / 2.0
        let originY = (drawableSize.height - vpHeight) / 2.0

        encoder.setViewport(MTLViewport(originX: Double(originX),
                                        originY: Double(originY),
                                        width: Double(vpWidth),
                                        height: Double(vpHeight),
                                        znear: 0.0,
                                        zfar: 1.0))

        // Write uniforms now that the viewport scale is known.
        // scaleY = output pixels per source row (drives scanline strength/fade).
        let scaleY = Float(vpHeight / CGFloat(frameHeight))
        var uniforms = Uniforms(invertFlash: lastInvertFlash ? 1 : 0,
                                smoothing: displayMode == .smooth ? 1 : 0,
                                scanlines: displayMode == .scanlines ? 1 : 0,
                                crt: displayMode == .crt ? 1 : 0,
                                scaleY: scaleY)
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
        uniformBuffer.didModifyRange(0..<MemoryLayout<Uniforms>.stride)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(screenTexture, index: 0)
        encoder.setFragmentTexture(attrTexture, index: 1)
        encoder.setFragmentBuffer(paletteBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(borderBufferGPU, offset: 0, index: 1)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 2)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Drag & drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
           let paths = board as? [String],
           let path = paths.first {

            let fileExtension = (path as NSString).pathExtension.lowercased()
            if fileExtension == "zip" ||
               SupportedGameTypes.allCases.first(where: { $0.rawValue == fileExtension }) != nil {
                return .copy
            }
        }

        return []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let filePath = board.firstObject as? String {
            dragDelegate?.loadGame(URL(fileURLWithPath: filePath))
            return true
        }

        return false
    }
}
