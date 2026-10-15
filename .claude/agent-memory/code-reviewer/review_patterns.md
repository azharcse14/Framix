---
name: review-patterns
description: Recurring issues seen when reviewing Framix branches (FFI soundness, scope creep into other planned tasks)
metadata:
  type: project
---

Recurring review findings in Framix (first seen P1-008, 2026-10-15):

- Scope creep into already-planned tasks: config/profile tweaks (e.g. strip/LTO/codegen-units = SEC-020, debug symbol split = GOT-005) slip into an unrelated task branch while the owning task stays todo.
  **Why:** tasks.json has ~600 fine-grained tasks; almost any "extra" already has an ID.
  **How to apply:** for every non-test change outside the task title, grep tasks/tasks.json titles for it and flag as Warning naming the owning task.

- `pub extern "C" fn` that dereferences a raw pointer carried inside a #[repr(C)] struct is declared safe; clippy's not_unsafe_ptr_arg_deref does not catch struct fields, so check.sh stays green.
  **Why:** ffi crate is also an rlib, so safe Rust can trigger UB.
  **How to apply:** check every exported fn taking pointer-bearing structs is `unsafe extern "C"` with a `# Safety` doc; note if fixing it would touch frozen tests (needs user approval).

- Stub-first test commits: verify each test actually fails against the stub; some (null/empty cases) pass on stubs.
