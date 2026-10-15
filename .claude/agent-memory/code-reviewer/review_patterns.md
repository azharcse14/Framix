---
name: review-patterns
description: Recurring issues seen when reviewing Framix branches (FFI soundness, scope creep, stub tests passing, constructor domain wider than invariants)
metadata:
  type: project
---

Recurring review findings in Framix (first seen P1-008, 2026-10-15):

- Scope creep into already-planned tasks: config/profile tweaks (e.g. strip/LTO/codegen-units = SEC-020, debug symbol split = GOT-005) slip into an unrelated task branch while the owning task stays todo.
  **Why:** tasks.json has ~600 fine-grained tasks; almost any "extra" already has an ID.
  **How to apply:** for every non-test change outside the task title, grep tasks/tasks.json titles for it and flag as Warning naming the owning task.
  Seen P1-014 re-review: a dependency-age fix also downgraded crates already locked on main (libc, zerocopy); lockfile cooldown belongs to SEC-028/TC-003. Diff Cargo.lock against main and ask whether each changed crate is in the new dep's tree.

- `pub extern "C" fn` that dereferences a raw pointer carried inside a #[repr(C)] struct is declared safe; clippy's not_unsafe_ptr_arg_deref does not catch struct fields, so check.sh stays green.
  **Why:** ffi crate is also an rlib, so safe Rust can trigger UB.
  **How to apply:** check every exported fn taking pointer-bearing structs is `unsafe extern "C"` with a `# Safety` doc; note if fixing it would touch frozen tests (needs user approval).

- Stub-first test commits: verify each test actually fails against the stub; some (null/empty/None cases) pass on stubs. Seen again ENG-005 (Rate::new stub returned None, so the zero-parts test passed).

- Constructors accept a wider domain than the invariants hold for; proptests only sample the narrow "sane" range, so the gap is invisible. ENG-005: Rate::new allowed num > den*TICKS_PER_SECOND, breaking monotonic/round-trip; a frozen test even used such a rate.
  **Why:** frozen tests then lock in the invalid value, so the proper fix needs user approval.
  **How to apply:** for every validating constructor, check the property-test ranges cover the full accepted domain; compute a counterexample at the boundary.
  Seen again P1-014: insert_clip accepted negative start/source_start, so Timeline::duration() could go negative (testing.md "durations never negative").

- Pub-field structs whose methods rely on an invariant "checked at insert" (P1-014 Clip::end assumes start+duration fits). External code can build the struct literally and break it; release has no overflow-checks.
  **How to apply:** suggest `#[non_exhaustive]` (keeps pub reads, blocks outside literals, does not break frozen tests that read fields).

- Proptests that drop results (`let _ = op(...)`) and only check invariants pass trivially if the op rejects everything; ask for an Ok-iff-model check in a new test.

- Frozen-test edits: the user told the implementer not to ask for decisions, so testing.md "stop and ask" conflicts get resolved by a separate test-only commit before the impl commit (seen P1-023). Accept it only if the edit corrects a wrong model without dropping assertions AND the test still fails on the stub (a committed proptest-regressions seed that fails on the stub proves this deterministically). Require a task.py note so the human sees it.
  **How to apply:** diff test-commit..fix-commit, then fix-commit..HEAD on test paths must be empty.

- `prop_assume!(f(x).is_some())` gates on the function under test (ENG-048). OK only if (a) rejection rate is computed and tiny, (b) another test unwraps f over a provably-representable range (spurious None caught), (c) all-None still fails via proptest's global reject limit. Better: an independent oracle for the None condition.
  Also ENG-048: no app/.gitignore on main, so `flutter` runs leave generated app/ios, app/android files (absolute paths, gradle-wrapper.jar) that get swept into commits. Always check `git show --stat` for app/ generated files. (GOT-004 adds app/.gitignore from flutter create; still check for local.properties / Generated.xcconfig leaks.)

- `flutter create` template defaults committed unreviewed (GOT-004): Android label lowercase "framix" (app name is Framix), Gradle wrapper/AGP from the template not docs/toolchain.md, boilerplate README, `package:flutter/material.dart` + `uses-material-design` although toolchain.md says new code uses material_ui/cupertino_ui.
  **How to apply:** for any app/ scaffold or Gradle/Xcode change, diff versions and names against docs/toolchain.md and ADR 0001; pins belong to TC-002.

- Design drift from docs/architecture.md crate table without an ADR (P1-023: memento undo, while the table says core owns "undo commands"). Flag as Warning: update the table via a short ADR.

- Memento/snapshot undo also restores id allocators inside the snapshot (Timeline::next_id), so ids get reused after undo + new edit. Check any snapshot-restore code for allocator rollback.
  P1-043 fix bumped the counter (max) after each swap and made Timeline's PartialEq ignore next_id so frozen undo tests still pass. Side effect: `==` no longer proves two timelines behave the same, so any later round-trip test (save/load P1-009, crash recovery) can pass with a lost/zeroed counter -> duplicate live ids.
  **How to apply:** when a review touches serialization/restore of Timeline, require an explicit next-id check (e.g. add_track on both, compare ids), not just `==`. Also check ADR text that described the bug is updated when the bug is fixed.

- Generated-artifact leaks from "prove the check works" experiments (P1-007): implementer edited a Rust doc comment, ran `cbindgen --verify`, reverted the source but committed the header containing the edit. `cbindgen --verify` (0.29.4) WRITES the new header even when it fails, so a second check.sh run goes green while the tree is dirty.
  **How to apply:** for any committed generated file, always run check.sh and `git status` afterwards; restore with `git checkout -- <file>` if the check mutated it. Freshness checks should regenerate + `git diff --exit-code`, covering every generated layer (header AND Dart bindings), not just the first.

- Dart wrappers around native handles (P1-006 FramixEngine): no `_disposed` guard, so send-after-dispose or double dispose passes a freed pointer to Rust (UAF from safe Dart). Check every Dart class holding a Pointer for a closed-state guard.
  Same review: a "dispose closes the stream" Dart test passed on a `Stream.empty()` stub (stub-first pattern again; check Dart stubs too, not just Rust).

- New codegen tool added without pinning (P1-006: protoc unchecked in gen_ffi.sh, protoc_plugin/protox/buf missing from docs/toolchain.md "FFI codegen" row). For any new generator, require the version in toolchain.md and a version check in the script, like cbindgen.

- First-screen tasks absorb foundation tasks (ENG-003 did L10N-001 gen-l10n/ARB, DS-003 hand-built ColorScheme, ENG-002 bloc/get_it while those stayed todo). Flag Warning; ask for task.py notes on the owning tasks so they are not redone.
- Hand-built ColorScheme maps primary=accentFill (#6E4CF5); M3 OutlinedButton/TextButton then draw accentFill text on background = ~3.7:1, below the 4.5:1 rule (design-system says accentText for accent text on dark). Check component themes whenever a screen uses non-filled buttons.
- Generated l10n (app/lib/l10n/generated) committed but check.sh's `git diff --exit-code` only covers ffi/proto paths; flag until the l10n path is added (same family as the cbindgen freshness gap).
- Dart UI deriving display data from list position (ENG-003 "Video track {index+1}" across all kinds) = numbering/naming rule in Dart and wrong with mixed kinds; the engine should carry name/number.
