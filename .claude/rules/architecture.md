# Architecture

## Rust engine layers (dependencies point inward only)
- `core`: timeline model, time, keyframes, project format. Pure Rust: no I/O, no wgpu, no FFI, no threads.
- `app`: command handling, undo (snapshot history, ADR 0002), autosave, export orchestration, entitlement and watermark. Depends on `core` and on port traits only.
- Adapters `render` (wgpu), `media` (platform decoder/encoder callbacks, FFmpeg fallback), `audio` (cpal), `storage` (files): implement the ports.
- `ffi`: thin boundary. Decode Protobuf command -> call `app` -> encode event. No logic.
- Ports are traits owned by core/app (Decoder, Encoder, Clock, Storage, Renderer). Tests use in-memory fakes.

## Flutter
- Feature folders: app/lib/features/<feature>/{view,bloc}. Shared widgets in app/lib/core/ui, engine gateway in app/lib/core/engine.
- No domain model in Dart beyond what engine events carry; never re-implement engine rules in Dart.

## Platform (Swift/Kotlin)
- Thin adapters: wrap OS APIs and expose them to Rust through the C ABI callbacks. No business logic.

## Reuse, not duplication
- Before writing a new function, type, widget, constant, or shader, Grep for an existing one; extend it if it fits.
- One home per piece of knowledge: a rule, constant, or format is defined once. Two similar-looking lines are fine; extract on the third repeat, or as soon as it is the same rule.
- Shared code goes to the lowest layer that needs it, never a catch-all `utils` module.
- WGSL has no include: shared shader functions live in engine/render/shaders/common/ and are composed at build time.
- No abstraction for a single caller "for later".

## Code
- Small, single-purpose functions; names say what, not how.
- Rust errors: typed `Result` (thiserror). No `unwrap`/`expect` outside tests unless the invariant is proven in a comment. Dart: no empty catch.
- No new dependency without asking (license, app size, maintenance).
- `#[allow(...)]` or `// ignore:` only with a reason comment.
- Public items have doc comments. Architecture decisions go to docs/adr/NNNN-title.md.
- No drive-by refactors; unrelated cleanup is a separate task (`task.py add`).

## Security
- Treat every media file, project/template file, downloaded asset, and deep link as untrusted: validate, cap sizes, no path traversal on extract.
- Templates and downloadable effects are data only (parameters, LUT, images); never code or shaders.
- Downloaded models/assets load only after the signed manifest hash matches.
- No secret or privileged key in the app. Logs and Sentry never contain user media, file paths, or personal data.
