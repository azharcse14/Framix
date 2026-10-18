// The callbacks only iOS can serve, registered into the engine at startup
// (docs/adr/0003-platform-callbacks.md). Thin adapter: the engine decides what to draw and when.
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
