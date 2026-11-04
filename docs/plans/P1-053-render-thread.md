# P1-053 plan: preview draws off the hot command path (first slice)

Status: first slice (2026-11-04). The rest of P1-053 needs devices (see Follow-ups).

## Problem
- Scrubbing sends one Seek per touch sample; each one redraws (decode + GPU) synchronously on
  the engine thread before the next Seek is read, so the preview lags behind the finger.
- A redraw that fails on the GPU clears the shown texture silently; the preview never redraws
  again and Dart never learns it.

## Slice 1 (this change, host-testable)
1. Coalesce redraws (latest wins). `app::Engine` gets `handle_deferred(command)`: same reply as
   `handle`, but a moved playhead or a changed picture only marks the preview stale.
   `Engine::flush_preview()` draws the stale preview once, at the current playhead.
   `handle` stays `handle_deferred` + flush, so the existing callers and tests keep their
   eager behaviour.
   The FFI serve loop uses `handle_deferred` and calls `flush_preview()` only when the inbox is
   empty (`try_recv` -> Empty), before it blocks. N queued Seeks = N PlayheadChanged replies, one
   draw for the last position. Every command is still answered with exactly one event, in order.
2. Preview loss is an event. New `Event.preview_lost = 12` (`PreviewLost{texture_id}`),
   unsolicited, sent once when a redraw fails with `DrawError::Gpu`. `flush_preview()` returns
   it. Protocol 39 -> 40 (additive oneof field; buf breaking passes).
   Dart: `PreviewCubit` on PreviewLost emits null (stop showing the dead texture) and sends
   CreatePreview again.

## Not in this slice
- A separate render thread. With coalescing the engine thread does at most one draw per idle
  point; moving draw to its own thread needs the GPU sync below to be useful and safe.

## Ordering guarantees (tests)
- app: deferred Seeks draw nothing until flush; one flush draws once at the last time.
- app: a GPU failure in a redraw yields exactly one PreviewLost with the shown texture id;
  a new CreatePreview + texture brings redraws back.
- Dart: PreviewCubit resends CreatePreview on PreviewLost and clears its texture id.

## Follow-ups (device-only)
- Render thread with GPU sync: iOS MTLSharedEvent signal/wait instead of a CPU wait per draw;
  Android EGL native fence -> Vulkan semaphore, release barrier to QUEUE_FAMILY_FOREIGN_EXT,
  per-format blit pipeline (replaces the spike lock + fence wait + glFinish).
- iOS double buffering (two IOSurfaces, swap on GPU completion); Android has it via
  SurfaceProducer's ImageReader (ADR 0004).
- Keep one Android wgpu surface instead of one per draw.
- Decode off the engine thread (decode workers) so a slow decode never delays command replies.
