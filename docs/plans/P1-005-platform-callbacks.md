# P1-005 plan: Rust <-> platform callbacks (draft, not yet an ADR)

Status: proposed. Needs ADR 0003 before code. Blocked on: the `render` crate exists only on the
P1-001 spike branch (spike code stays off main), so it must be promoted (reviewed, SPIKE
markers removed) first. Decision for the user.

## Same library instance
- iOS: Runner does not link `framix_ffi.framework`; Dart `dlopen`s it. Swift does
  `dlopen("framix_ffi.framework/framix_ffi", RTLD_NOW)` + `dlsym("engine_platform_register")`
  in `didInitializeImplicitFlutterEngine`; dyld returns the same image, so statics are shared.
  Types come from the cbindgen header via `Runner-Bridging-Header.h` (no new generated code).
  Risk: the path string follows native-assets naming; fail loudly on a dlsym miss.
- Android (later): `System.loadLibrary("framix_ffi")` gets the same `.so`; Kotlin cannot hand out
  C function pointers, so a small Rust JNI shim (needs the `jni` crate: ask first) fills the
  same vtable.

## C ABI
```c
typedef void (*FramixTextureDone)(void *done_ctx, int32_t status, int64_t texture_id,
                                  void *mtl_texture);
typedef struct FramixPlatform {
  uint32_t version;   // FRAMIX_PLATFORM_VERSION = 1
  void *ctx;          // process lifetime
  void (*create_preview_texture)(void *ctx, uint32_t w, uint32_t h,
                                 FramixTextureDone done, void *done_ctx);
  void (*frame_available)(void *ctx, int64_t texture_id);
} FramixPlatform;
int32_t engine_platform_register(const FramixPlatform *p);  // OnceLock; NULL/PROTOCOL/ALREADY
```
- Rust calls the vtable on the engine thread; callbacks return at once. Swift hops with
  `DispatchQueue.main.async` (never `main.sync`: engine_destroy joins from the main thread).
- `done` is a Rust `extern "C"` fn wrapped in `ffi_guard`; it only enqueues
  `EngineMessage::PreviewTexture`. Swift calls it exactly once, any thread.
- `engine_destroy` must send `EngineMessage::Shutdown` before joining (a pending `done_ctx`
  holds a Sender clone, so dropping the sender no longer ends the loop).
- Move `ENGINE_ERR_GPU` next to the other error codes; add `ENGINE_ERR_ALREADY`.
- Swift 6: `@convention(c)` closures capture nothing; pass pointers as `UInt(bitPattern:)`
  across `main.async`. Set `SWIFT_VERSION = 6.0` (pbxproj still says 5.0).

## First use: preview texture
`Command.CreatePreview{width,height}` -> engine calls `create_preview_texture` -> Swift builds the
IOSurface CVPixelBuffer + MTLTexture (from the spike), registers the FlutterTexture, calls
`done(ok, id, mtl)` -> engine stores it, emits `Event.PreviewReady{texture_id}`, renders, waits,
calls `frame_available`. Dart only sees the texture id. Protocol 5 -> 6. Rendering stays on the
engine thread for now; a render thread with MTLSharedEvent double buffering is a later task.

## Tests
Host (`engine/ffi/tests/platform.rs`, fake vtable of `extern "C"` fns): register rejects null,
wrong version, double call; fake create calls `done` from another thread -> PreviewReady;
error status -> CommandFailed; unregistered -> CommandFailed; engine_destroy returns when `done`
is never called. Simulator: dlopen/dlsym path, main-thread registration, picture on screen.

## Commits
1. test: platform.rs + proto messages. 2. feat(ffi): platform.rs, Shutdown, error codes,
cbindgen export, ADR 0003, ffi rules. 3. feat(ios): native/ios adapter, bridging header,
AppDelegate registration, Swift 6, Dart PreviewReady; delete the spike channel.

Open: dlopen path on device builds; whether FlutterTextureRegistry.register needs the main
thread (assume yes); textures never unregistered yet; `jni` crate approval for Android.
