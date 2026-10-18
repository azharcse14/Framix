# P1-005 plan: Rust <-> platform callbacks

Status: in progress (2026-10-18). Decision record: docs/adr/0003-platform-callbacks.md.
The render crate reached main with the P1-001 spike, so the blocker is gone.

## Scope
- C ABI: `EnginePlatform` vtable + `engine_platform_register` (process-wide, set once).
- `app` ports `PreviewHost` (platform texture + frame signal) and `PreviewRenderer` (GPU);
  the preview flow lives in `app::Engine`, `ffi` only adapts (vtable -> host, render::Gpu ->
  renderer, `done` callback -> engine message).
- iOS: native/ios adapter registers the vtable at init; the Dart preview asks the engine
  (`CreatePreview`) instead of the spike method channel. The iOS spike channel is deleted.
- Android keeps the P1-001 JNI spike until its vtable task (Kotlin cannot hand out C function
  pointers; calling Kotlin from Rust needs JNI calls). Filed as a follow-up.

## Wire
- `Command.CreatePreview{width,height}` (1..=8192). Immediate reply `CommandAccepted`, or
  `CommandFailed` (bad size, no platform). Later, unsolicited: `PreviewReady{texture_id}` or
  `CommandFailed`. Protocol 9 -> 10.

## Flow
CreatePreview -> host.create_texture (platform callback, returns at once) -> Swift builds the
IOSurface CVPixelBuffer + MTLTexture on the main queue, registers the FlutterTexture, calls
`done(ctx, OK, id, mtl)` -> `done` posts `EngineMessage::PreviewTexture` -> engine thread:
renderer.draw(mtl), host.frame_available(id), emit PreviewReady.

## Shutdown
`done_ctx` owns a Sender clone and the engine loop holds one for its host, so dropping the
handle's sender no longer ends the loop: `engine_destroy` sends `Shutdown` before joining.
A `done` that never comes leaks one boxed Sender, never hangs destroy.

## Tests
- app/tests/engine_preview.rs (fakes): accepted + texture requested; ready -> drawn into that
  texture, frame signalled, PreviewReady; platform error / draw error -> CommandFailed with no
  frame signal; bad sizes and no host -> CommandFailed with nothing requested.
- ffi/tests/platform.rs (fake vtable of extern "C" fns, one registration per test binary):
  register rejects null, wrong version, a second call; CreatePreview -> CommandAccepted; a
  failing `done` from another thread -> CommandFailed; destroy returns when `done` never comes.
- Simulator: picture on screen through the new path.

## Later (filed)
- Render thread + MTLSharedEvent double buffering (rendering stays on the engine thread here).
- Android vtable through JNI; textures are never unregistered yet.
