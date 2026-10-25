//
//  MetalScreenView.swift
//  speccyMac
//
//  Renders the emulator's CPU-built 320x288 frame bitmap using Metal.
//  Level 1 approach: the Spectrum still builds the RGBA bitmap on the CPU,
//  but instead of allocating a CGImage every frame we upload the bytes into
//  a reused Metal texture and draw it as a single textured quad. This removes
//  the per-frame CGImage allocation and gives precise vsync-paced presentation.
//

import Cocoa
import Metal
import MetalKit

final class MetalScreenView: MTKView {

    // Native Spectrum frame size (screen + border), matching Spectrum.bmpData.
    private let frameWidth  = 320
    private let frameHeight = 288

    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var screenTexture: MTLTexture!
    private var sampler: MTLSamplerState!

    // Whether to smooth (linear) or keep pixels crisp (nearest) when scaling.
    private var useLinearFiltering = false

    weak var dragDelegate: DragDelegate?

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
        // Letterbox the 4:3-ish Spectrum image against a black surround.
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        layer?.magnificationFilter = .nearest

        commandQueue = device.makeCommandQueue()

        buildPipeline(device: device)
        buildTexture(device: device)
        buildSampler(device: device)

        registerForDraggedTypes([.fileURL])
    }

    // MARK: - Metal setup

    private func buildPipeline(device: MTLDevice) {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        // Fullscreen textured quad generated from the vertex id (no vertex buffer).
        vertex VertexOut screen_vertex(uint vid [[vertex_id]]) {
            float2 positions[4] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };
            // Flip V so the top of the bitmap appears at the top of the view.
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

        fragment float4 screen_fragment(VertexOut in [[stage_in]],
                                        texture2d<float> tex [[texture(0)]],
                                        sampler smp [[sampler(0)]]) {
            // The emulator packs each pixel as 0x00RRGGBB with 0xFF in the low
            // (alpha) byte, i.e. memory bytes A R G B. A .bgra8Unorm texture
            // reads those bytes as B=A, G=R, R=G, A=B, so remap to recover the
            // true colour and force full opacity.
            float4 c = tex.sample(smp, in.texCoord);
            return float4(c.g, c.r, c.a, 1.0);
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

    private func buildTexture(device: MTLDevice) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: frameWidth,
            height: frameHeight,
            mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .managed
        screenTexture = device.makeTexture(descriptor: descriptor)
    }

    private func buildSampler(device: MTLDevice) {
        updateSampler(device: device)
    }

    private func updateSampler(device: MTLDevice) {
        let descriptor = MTLSamplerDescriptor()
        let filter: MTLSamplerMinMagFilter = useLinearFiltering ? .linear : .nearest
        descriptor.minFilter = filter
        descriptor.magFilter = filter
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: descriptor)
    }

    // MARK: - Public API

    /// Toggle between crisp (nearest) and smoothed (linear) scaling.
    func toggleFiltering() {
        useLinearFiltering.toggle()
        if let device = device {
            updateSampler(device: device)
        }
        setNeedsDisplay(bounds)
    }

    /// Upload a freshly built 320x288 BGRA frame and request a redraw.
    /// `pixels` must point to frameWidth * frameHeight UInt32 values.
    func updateFrame(_ pixels: UnsafePointer<UInt32>) {
        let region = MTLRegionMake2D(0, 0, frameWidth, frameHeight)
        screenTexture.replace(region: region,
                              mipmapLevel: 0,
                              withBytes: pixels,
                              bytesPerRow: frameWidth * 4)
        setNeedsDisplay(bounds)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
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
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Drag & drop (preserve existing behaviour from EmulatorImageView)

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
