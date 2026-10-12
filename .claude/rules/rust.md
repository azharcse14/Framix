---
paths:
  - "engine/**/*.rs"
  - "engine/**/Cargo.toml"
---
# Rust
- Edition 2024, toolchain from rust-toolchain.toml. clippy -D warnings clean.
- Respect the crate layering in .claude/rules/architecture.md; `core` never depends on I/O, wgpu, FFI, or threads.
- Typed errors with thiserror; no unwrap/expect outside tests without a proven-invariant comment.
- Time uses the rational tick type from `core`; never f32/f64 seconds.
- `// SAFETY:` on every unsafe block, stating the invariant.
- Hot paths follow .claude/rules/performance.md; add or update the criterion benchmark when you touch one.
- Release profile keeps panic = "unwind" (FFI uses catch_unwind), strip, LTO, codegen-units = 1, and --remap-path-prefix.
