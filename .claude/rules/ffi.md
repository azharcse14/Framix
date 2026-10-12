---
paths:
  - "proto/**"
  - "engine/ffi/**"
  - "app/lib/core/engine/**"
---
# FFI and Protobuf
- Boundary is engine_create (with protocol version), engine_send, engine_set_event_callback, engine_destroy, engine_free_*; add functions only with an ADR.
- Every exported fn: catch_unwind, error code on failure, returns immediately (work goes to the engine thread).
- Rust-to-Dart callbacks only through NativeCallable.listener.
- Memory allocated in Rust is freed only through engine_free_*.
- Proto: never reuse or renumber field numbers; `reserved` for removed fields and names; new fields optional with safe defaults.
- Any breaking-looking change must pass `buf breaking`; bump the protocol version when the contract changes.
- Regenerate bindings with scripts/gen_ffi.sh; never hand-edit generated code.
