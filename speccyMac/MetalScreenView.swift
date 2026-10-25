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

    // Per-frame uniforms (flash invert flag).
    private var uniformBuffer: MTLBuffer!

    // Whether to smooth (linear) or keep pixels crisp (nearest) when scaling.
    private var useLinearFiltering = false

    weak var dragDelegate: DragDelegate?

    // Matches the Uniforms struct in the shader.
    private struct Uniforms {
        var invertFlash: UInt32
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

        fragment float4 screen_fragment(VertexOut in [[stage_in]],
                                        texture2d<uint> screenTex [[texture(0)]],
                                        texture2d<uint> attrTex   [[texture(1)]],
                                        constant float4 *palette   [[buffer(0)]],
                                        constant uchar  *borderLine [[buffer(1)]],
                                        constant Uniforms &uniforms [[buffer(2)]]) {

            // Map the normalised texCoord to an integer pixel in the 320x288 frame.
            uint px = min(uint(in.texCoord.x * float(kFrameWidth)),  kFrameWidth  - 1u);
            uint py = min(uint(in.texCoord.y * float(kFrameHeight)), kFrameHeight - 1u);

            // Border regions: anything outside the central 256x192 screen area.
            bool inScreenX = (px >= kBorderLeft) && (px < kBorderLeft + kScreenWidth);
            bool inScreenY = (py >= kBorderTop)  && (py < kBorderTop + kScreenHeight);

            if (!(inScreenX && inScreenY)) {
                uint idx = uint(borderLine[py]) & 0x07u;
                return palette[idx];
            }

            // Screen pixel coordinates (0..255, 0..191).
            uint sx = px - kBorderLeft;
            uint sy = py - kBorderTop;

            uint col = sx >> 3;          // 0..31  (cell column)
            uint bit = sx & 7u;          // 0..7   (MSB first)
            uint row = sy;               // 0..191 (attribute stored per row)

            uint byte = screenTex.read(uint2(col, row)).r;
            uint attr = attrTex.read(uint2(col, row)).r;

            // Resolve ink/paper with bright and flash.
            uint bright = (attr & 0x40u) != 0u ? 8u : 0u;
            uint inkIdx   = (attr & 0x07u) + bright;
            uint paperIdx = ((attr & 0x38u) >> 3) + bright;

            if (uniforms.invertFlash != 0u && (attr & 0x80u) != 0u) {
                uint t = inkIdx; inkIdx = paperIdx; paperIdx = t;
            }

            // Select ink or paper for this bit (MSB first).
            bool pixelSet = (byte & (0x80u >> bit)) != 0u;
            return pixelSet ? palette[inkIdx] : palette[paperIdx];
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

    /// Toggle between crisp (nearest) and smoothed (linear) scaling.
    func toggleFiltering() {
        useLinearFiltering.toggle()
        layer?.magnificationFilter = useLinearFiltering ? .linear : .nearest
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

        var uniforms = Uniforms(invertFlash: invertFlash ? 1 : 0)
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
        uniformBuffer.didModifyRange(0..<MemoryLayout<Uniforms>.stride)

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
            if SupportedGameTypes.allCases.first(where: { $0.rawValue == fileExtension }) != nil {
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
