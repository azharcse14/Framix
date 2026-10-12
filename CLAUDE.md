# Framix
Photo and video editor. Flutter is UI only; all logic lives in the Rust engine.
App name Framix, bundle ID com.travela.framix, minimum iOS 17 / Android 10 (API 29), Android ABIs arm64-v8a + x86_64 (docs/adr/0001-product-basics.md).
The full plan is docs/plan.md; read the section you need, never all of it.

@docs/architecture.md
@docs/toolchain.md

## Layout
- app/: Flutter UI (Bloc, go_router, get_it)
- engine/: Rust workspace (core, app, render, media, audio, storage, ffi)
- native/ios (Swift 6), native/android (Kotlin): thin platform layer
- proto/: FFI command/event and project file Protobuf schema
- tasks/tasks.json + scripts/task.py: task tracker (see "Task tracking")
- docs/: plan.md (master plan), architecture.md, toolchain.md, design-system.md, adr/, TASKS.md (generated)
- tests/media/: test media corpus (git LFS)

## Commands
- All checks: `scripts/check.sh` (`--quick` = changed parts only)
- Tasks: `python3 scripts/task.py next | start <ID> | done <ID> --commit <sha> | note <ID> "..." | add <PREFIX> "..." | list --status in_progress`
- Flutter: `fvm flutter analyze`, `fvm flutter test`
- Rust: `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, `cargo bench`
- Codegen: `scripts/gen_ffi.sh` (cbindgen, ffigen, prost)

## Rules
- No business logic in Dart; Dart sends commands and renders state from engine events.
- Never send video frames to Dart; preview goes through Texture.
- Every exported FFI fn is wrapped in catch_unwind; free Rust memory via engine_free_*.
- Audio callback: no allocation, no locks, no I/O.
- Time is integer/rational ticks, never floating-point seconds.
- Every `unsafe` block has a `// SAFETY:` comment.
- Never edit generated files (*.g.dart, ffi bindings, generated proto, docs/TASKS.md).
- UI text only via AppLocalizations (en, bn); colors and fonts only via theme tokens (docs/design-system.md).
- Use the versions in docs/toolchain.md; no deprecated APIs. If unsure about an API, check the official docs.
- Prefer Rust; C/C++ only through the wrappers listed in docs/plan.md (Tool review).
- Entitlement checks and the watermark live in the Rust engine; Dart only asks the engine.
- Proto and project format: never reuse or renumber field numbers; reserve removed ones.
- Detailed rules live in .claude/rules/ (testing, architecture, performance, plus per-language); follow them.

## Workflow (every task)
0. Take one task ID (from me, or `task.py next`). Run `python3 scripts/task.py start <ID>`.
1. Understand the task. Search the codebase for code that already does this or something close; reuse or extend it. If anything is unclear, ask before coding.
2. Anything touching engine/, ffi, threading, or the project format: plan mode first.
3. Write failing tests, run them, show the failing assertion. Commit the tests alone.
4. Implement the smallest change that passes. Do not modify the tests from step 3.
5. Run `scripts/check.sh`. Everything green, zero new warnings.
6. Delegate review to the `code-reviewer` subagent. Fix every Critical item, rerun step 5, and re-review if the fix was not trivial.
7. Run `python3 scripts/task.py done <ID> --commit <sha>` and commit tasks/ and docs/ changes.
8. Report: task ID, what changed, check results, reviewer verdict, open Warnings, assumptions made.

## Task tracking
- Statuses: todo, in_progress, done. Change them only with scripts/task.py; never edit tasks/tasks.json, docs/TASKS.md, or plan.md checkboxes by hand.
- Mark done only after check.sh is green and the reviewer approved.
- Found extra work (bug, missing piece)? File it with `task.py add <PREFIX> "<title>" --tags ...` and tell me; don't silently grow the current task.
- Blocked? Keep it in_progress, run `task.py note <ID> "blocked: <reason>"`, and tell me.
- Tasks with owner "human" (store, legal, process, device checks): never start or close them; you may add notes.
- One in_progress task per branch.
