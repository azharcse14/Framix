# 0003. Platform layer registers a C vtable; async platform work answers through the engine queue
Status: proposed
Date: 2026-10-18
Task: P1-005

## Context
Some work only the platform layer can do: Flutter textures (FlutterTextureRegistry on iOS,
SurfaceProducer on Android), hardware codecs, OS ML. That work often has to run on the main
thread, while the engine runs on its own thread and `engine_destroy` joins it from the main
thread, so the engine must never wait for the platform synchronously. The P1-001 spike used a
method channel and let Dart pass a raw `id<MTLTexture>` back to Rust, which put platform
plumbing in Dart.

## Decision
- New C ABI: `EnginePlatform { version, ctx, create_preview_texture, frame_available }` and
  `engine_platform_register(const EnginePlatform*)`. Process-wide, set once
  (`ENGINE_ERR_ALREADY` after that), version-checked (`ENGINE_PLATFORM_VERSION`).
- Callbacks are called on the engine thread and must return at once. Results come back through
  a Rust `done(done_ctx, status, ...)` callback the platform calls exactly once from any
  thread; it only posts a message to the engine queue.
- `app` owns the ports (`PreviewHost`, `PreviewRenderer`) and the flow; `ffi` adapts the vtable
  and the render crate to them.
- A command whose result needs the platform is answered at once with `CommandAccepted`; the
  result comes later as an unsolicited event (`PreviewReady`, or `CommandFailed`). Export will
  follow the same pattern.
- `engine_destroy` sends an explicit `Shutdown`, since pending `done` contexts keep the queue open.
- iOS registers in `didInitializeImplicitFlutterEngine` by resolving the symbol from the
  already bundled engine library (no extra link step, same image Dart uses).

## Consequences
- Dart only sees texture ids; no handles or method channels for engine work.
- A platform that never calls `done` leaks one small context but cannot hang shutdown.
- Rendering still runs on the engine thread until the render thread task lands.
- Android needs a JNI shim to fill the same vtable (Kotlin has no C function pointers); until
  then Android keeps the P1-001 spike path.
