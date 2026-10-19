// The callbacks only iOS can serve, registered into the engine at startup
// (docs/adr/0003-platform-callbacks.md). Thin adapter: the engine decides what to draw and when.
import AVFoundation
import CoreVideo
import Flutter
import IOSurface
import Metal

/// A Flutter texture whose CVPixelBuffer shares one IOSurface with the Metal texture the engine
/// (wgpu) renders into, so Flutter samples exactly the bytes the GPU wrote.
final class PreviewTexture: NSObject, FlutterTexture, @unchecked Sendable {
  // @unchecked: both fields are immutable after init; copyPixelBuffer runs on the raster thread.
  let pixelBuffer: CVPixelBuffer
  let metalTexture: MTLTexture

  init?(device: MTLDevice, width: Int, height: Int) {
    let attributes: [CFString: Any] = [
      kCVPixelBufferMetalCompatibilityKey: true,
      kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any](),
    ]
    var buffer: CVPixelBuffer?
    guard
      CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
        attributes as CFDictionary, &buffer) == kCVReturnSuccess,
      let buffer,
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    else { return nil }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    guard
      let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
    else { return nil }
    pixelBuffer = buffer
    metalTexture = texture
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    .passRetained(pixelBuffer)
  }
}

/// Fills the engine's `EnginePlatform` vtable. The engine calls it on its own thread; every
/// callback hops to the main queue and returns at once.
@MainActor
enum PlatformCallbacks {
  private static var registry: FlutterTextureRegistry?
  // ponytail: textures are never unregistered; the preview makes one per launch.
  private static var textures: [Int64: PreviewTexture] = [:]
  /// The engine library, for symbols the C header leaves out (spike entries).
  fileprivate static var engineLibrary: UnsafeMutableRawPointer?

  /// Registers with the engine library Dart loads (same image, so the same registration).
  static func register(with registrar: FlutterApplicationRegistrar) {
    registry = registrar.textures()
    typealias Register = @convention(c) (UnsafePointer<EnginePlatform>?) -> Int32
    guard
      let frameworks = Bundle.main.privateFrameworksPath,
      let library = dlopen("\(frameworks)/framix_ffi.framework/framix_ffi", RTLD_NOW),
      let symbol = dlsym(library, "engine_platform_register")
    else {
      return assertionFailure("engine library or engine_platform_register not found")
    }
    engineLibrary = library
    var platform = EnginePlatform(
      version: UInt32(ENGINE_PLATFORM_VERSION), ctx: nil,
      create_preview_texture: createPreviewTexture, frame_available: frameAvailable)
    let code = unsafeBitCast(symbol, to: Register.self)(&platform)
    assert(code == ENGINE_OK, "engine_platform_register failed: \(code)")
  }

  /// Answers `done` exactly once: OK with the texture, or a failure status.
  fileprivate static func makeTexture(
    width: Int, height: Int, done: EnginePreviewTextureDone, doneCtx: UnsafeMutableRawPointer?
  ) {
    guard
      let registry, let device = MTLCreateSystemDefaultDevice(),
      let texture = PreviewTexture(device: device, width: width, height: height)
    else { return done(doneCtx, ENGINE_ERR_GPU, 0, nil) }
    let id = registry.register(texture)
    textures[id] = texture
    done(doneCtx, ENGINE_OK, id, Unmanaged.passUnretained(texture.metalTexture).toOpaque())
  }

  fileprivate static func markFrameAvailable(_ id: Int64) {
    // SPIKE (P1-002): with FRAMIX_SPIKE_CLIP set (simulator: SIMCTL_CHILD_FRAMIX_SPIKE_CLIP),
    // the clip's first decoded frame replaces the test pattern. Unset in any shipped launch.
    if #available(iOS 26, *), let texture = textures[id],
      let clip = ProcessInfo.processInfo.environment["FRAMIX_SPIKE_CLIP"]
    {
      Task {
        await SpikeDecode.drawFirstFrame(of: URL(fileURLWithPath: clip), into: texture.metalTexture)
        registry?.textureFrameAvailable(id)
      }
      return
    }
    registry?.textureFrameAvailable(id)
  }
}

// C callbacks capture nothing; pointers cross to the main queue as integers.
private let createPreviewTexture:
  @convention(c) (
    UnsafeMutableRawPointer?, UInt32, UInt32, EnginePreviewTextureDone?, UnsafeMutableRawPointer?
  ) -> Void = { _, width, height, done, doneCtx in
    guard let done else { return }
    let ctx = UInt(bitPattern: doneCtx)
    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        PlatformCallbacks.makeTexture(
          width: Int(width), height: Int(height), done: done,
          doneCtx: UnsafeMutableRawPointer(bitPattern: ctx))
      }
    }
  }

private let frameAvailable: @convention(c) (UnsafeMutableRawPointer?, Int64) -> Void = { _, id in
  DispatchQueue.main.async {
    MainActor.assumeIsolated { PlatformCallbacks.markFrameAvailable(id) }
  }
}

/// SPIKE (P1-002): decodes one frame with AVAssetReader (VideoToolbox) into an IOSurface-backed
/// NV12 CVPixelBuffer and has the engine convert it into the preview, with no CPU copy: Metal
/// textures sit on the decoder's own IOSurface planes. The Decoder port replaces this.
@available(iOS 26, *)
@MainActor
enum SpikeDecode {
  typealias DrawNv12 =
    @convention(c) (
      UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UInt32,
      UInt32
    ) -> Int32

  static func drawFirstFrame(of clip: URL, into target: MTLTexture) async {
    do {
      let asset = AVURLAsset(url: clip)
      guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        return NSLog("framix spike: no video track")
      }
      let output = AVAssetReaderTrackOutput(
        track: track,
        outputSettings: [
          kCVPixelBufferPixelFormatTypeKey as String:
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
          kCVPixelBufferMetalCompatibilityKey as String: true,
          kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ])
      let reader = try AVAssetReader(asset: asset)
      let frames = reader.outputProvider(for: output)
      try reader.start()
      guard let sample = try await frames.next() else {
        return NSLog("framix spike: no frame")
      }
      let code = sample.withUnsafeSampleBuffer { buffer in
        guard let pixels = CMSampleBufferGetImageBuffer(buffer) else { return ENGINE_ERR_NULL }
        return draw(pixels, into: target)
      }
      NSLog("framix spike: draw_nv12 -> \(code)")
    } catch {
      NSLog("framix spike: decode failed: \(error)")
    }
  }

  /// Wraps the frame's two IOSurface planes as Metal textures and calls the engine.
  private static func draw(_ pixels: CVPixelBuffer, into target: MTLTexture) -> Int32 {
    guard
      CVPixelBufferGetPixelFormatType(pixels) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      let surface = CVPixelBufferGetIOSurface(pixels)?.takeUnretainedValue(),
      let library = PlatformCallbacks.engineLibrary,
      let symbol = dlsym(library, "engine_spike_draw_nv12")
    else { return ENGINE_ERR_NULL }
    let device = target.device
    func plane(_ index: Int, _ format: MTLPixelFormat) -> MTLTexture? {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: format, width: CVPixelBufferGetWidthOfPlane(pixels, index),
        height: CVPixelBufferGetHeightOfPlane(pixels, index), mipmapped: false)
      descriptor.usage = .shaderRead
      return device.makeTexture(descriptor: descriptor, iosurface: surface, plane: index)
    }
    guard let luma = plane(0, .r8Unorm), let chroma = plane(1, .rg8Unorm) else {
      return ENGINE_ERR_GPU
    }
    let matrix = CVBufferCopyAttachment(pixels, kCVImageBufferYCbCrMatrixKey, nil)
    let bt709: UInt32 = (matrix as? String) == (kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String) ? 0 : 1
    let opaque = { (texture: MTLTexture) in Unmanaged.passUnretained(texture).toOpaque() }
    // The planes must outlive the call: passUnretained alone lets Swift release them early.
    return withExtendedLifetime((luma, chroma)) {
      unsafeBitCast(symbol, to: DrawNv12.self)(
        opaque(target), opaque(luma), opaque(chroma), bt709, 1)
    }
  }
}
