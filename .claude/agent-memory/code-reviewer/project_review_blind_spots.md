---
name: review-blind-spots
description: Things scripts/check.sh does not catch in Framix reviews: protocol version bump, native (Swift/Kotlin) warnings, adapter placement
metadata:
  type: project
---

check.sh green does not cover these; check them by hand on every FFI/proto/native review.

- ENGINE_PROTOCOL_VERSION (engine/ffi/src/lib.rs) must be bumped for every proto contract change. `buf breaking` passes additive changes, so nothing fails if it is forgotten. History: every new command bumped it (1..9); P1-005 (2026-10-18) added CreatePreview/CommandAccepted/PreviewReady and forgot, even though its own plan said 9 -> 10.
- check.sh does not build iOS/Android, so Gradle/Xcode warnings are unverified unless `scripts/native_warnings.sh` was run; ask for its result when Swift/Kotlin changed. A green native_warnings run still does NOT prove Swift 6 strict concurrency: Runner was SWIFT_VERSION 5.0 at P1-005 (filed P1-054); check project.pbxproj before relying on it.
- Moving an adapter that does `unsafe` on a port value into a `pub` type can turn a crate-private invariant into a safe-API soundness hole (P1-005: `framix_render::GpuRenderer` is pub, `draw` takes `PlatformTexture` with a pub `handle: usize` and wraps it as id<MTLTexture>). Ask for an `unsafe fn new` carrying the contract instead of `Default`.
- Port adapters live in their adapter crate (precedent: framix_storage::FileStore implements app's ProjectStore, storage depends on app). Flag adapters that land in `ffi` instead (P1-005 put GpuRenderer in ffi).
- Dart doc on FramixEngine.events said "one per command"; contract changes to events tend to leave Dart gateway docs stale.

**Why:** these slipped past a green check.sh in P1-005.
**How to apply:** grep the proto diff, then confirm the version bump and gateway docs; ask for native_warnings output.
