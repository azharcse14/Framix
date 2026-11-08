# 0008. Retired commands are deprecated, not deleted
Status: accepted
Date: 2026-11-08
Task: P1-084, P1-087

## Context
SnapTrim (P1-074) and SnapMove (P1-076) replaced TrimClip and MoveClip in the app; no app
code sends the old commands, but frozen engine tests (engine_clip_ops.rs,
engine_move_clip.rs) still do. `buf breaking` uses the FILE rule set, which refuses deleting a
oneof field or a message even when its number is reserved. Two ways out: switch to WIRE_JSON
(or WIRE), which allows reserved removals, or keep the fields and only deprecate them.

The command proto ships in the same binary on both sides, so wire compatibility matters
little today; but FILE also guards the generated Dart and Rust API, the project format lives
in the same buf module, and deleting a handler would break the frozen tests.

## Decision
- A retired command keeps its oneof field, message and engine handler. The field and the
  message get `[deprecated = true]` / `option deprecated = true` and a comment naming the
  replacement and this ADR. Its number is never reused.
- No code outside the frozen tests sends a retired command. The compiler enforces this: prost
  marks the oneof variant `#[deprecated]`, protoc_plugin marks the Dart accessors
  `@Deprecated`, and clippy/analyze run with warnings as errors. Dart reports same-package
  deprecated use only through `deprecated_member_use_from_same_package`, so
  app/analysis_options.yaml enables it. prost ignores the message-level option: the Rust
  structs are not deprecated, but they cannot be sent without the deprecated variant.
- Only the engine's handler arm and the frozen test files carry `#[allow(deprecated)]`, each
  with a reason comment.
- `buf breaking` stays on FILE. TrimClip and MoveClip are the first retired commands.
- Retiring does not change the wire, so ENGINE_PROTOCOL_VERSION is not bumped.

## Consequences
- Retired messages stay in the schema and the generated code (small, dead weight).
- A retired command can be deleted later (field reserved, message removed) only together with
  its frozen test and a new ADR: either a move to WIRE_JSON, or a buf v2 per-rule exception
  (FIELD_NO_DELETE, MESSAGE_NO_DELETE) for that change.
