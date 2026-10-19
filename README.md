# Framix

Photo ar video editor. Flutter shudhu UI; shob logic Rust engine e. Bundle ID com.travela.framix, minimum iOS 17 ar Android 10 (API 29), ABI arm64-v8a + x86\_64 ([ADR 0001](docs/adr/0001-product-basics.md)).

## Architecture

Dart engine e Protobuf command pathay, engine Protobuf event diye state ferot dey. Video frame kokhono Dart e ashe na; preview wgpu theke Flutter Texture e jay. Swift/Kotlin shudhu OS media ar ML API er patla adapter, C ABI diye Rust e register hoy.

Bistarito: [docs/architecture.md](docs/architecture.md) (chhoto), [docs/plan.md](docs/plan.md) (master plan; je section dorkar shudhu oita poro).

## Repo layout

| Path | Ki |
| --- | --- |
| app/ | Flutter UI (Bloc, go\_router, get\_it); `hook/build.dart` Native Assets diye engine build kore |
| engine/ | Rust workspace (core, app, ffi; render, media, audio, storage ashbe) |
| native/ios, native/android | Swift 6 / Kotlin platform layer |
| proto/ | FFI command/event ar project file Protobuf schema |
| scripts/ | `check.sh`, `task.py`, `gen_ffi.sh`, `audit.sh` |
| tasks/tasks.json | Task tracker data (haate edit na) |
| docs/ | plan.md, architecture.md, toolchain.md, design-system.md, adr/, TASKS.md (generated) |
| tests/media/ | Test media corpus (git LFS) |
| CLAUDE.md, .claude/ | Claude Code instruction, rules, code-reviewer agent, settings |

## Setup

Version gula [docs/toolchain.md](docs/toolchain.md) e pin kora; oita mene cholo.

1. `git lfs install && git lfs pull`
2. Rust: `rust-toolchain.toml` nijei toolchain dhore. Codegen tool: `cargo install --locked cbindgen cargo-audit` (version toolchain.md e), `protoc`, `buf`, `dart pub global activate protoc_plugin`.
3. Flutter: version `.fvmrc` e pin kora; `fvm install` (ei version ta install kore), tarpor `cd app && fvm flutter pub get`.
4. iOS: Xcode (toolchain.md er version). Android: pinned NDK ar JDK 21.
5. Run: `cd app && fvm flutter run`. Android e `--target-platform android-arm64,android-x64`.

## Commands

```bash
scripts/check.sh            # shob check (Rust fmt/clippy/test, Flutter analyze/test, codegen, buf)
scripts/check.sh --quick    # shudhu bodlano part
scripts/gen_ffi.sh          # cbindgen + ffigen + prost codegen
scripts/audit.sh            # cargo audit + dart pub outdated (network lage)
```

Generated file (`*.g.dart`, FFI binding, generated proto, docs/TASKS.md) haate edit koro na; check.sh stale codegen e fail kore.

## Task tracking

Status: todo, in\_progress, done. ID gula docs/plan.md e (jemon `P1-012`). Board: [docs/TASKS.md](docs/TASKS.md).

```bash
python3 scripts/task.py next                           # porer task er suggestion
python3 scripts/task.py show P1-001
python3 scripts/task.py start P1-001                   # todo -> in_progress
python3 scripts/task.py note P1-001 "blocked: device lagbe"
python3 scripts/task.py done P1-001 --commit abc1234   # in_progress -> done
python3 scripts/task.py reopen P1-001 "regression"     # -> todo
python3 scripts/task.py add P1 "Fix seek drift on VFR clips" --tags Rust
python3 scripts/task.py list --status in_progress
```

- Script plan.md checkbox ar docs/TASKS.md nijei update kore; haate tick dio na.
- Owner "human" task (store, legal, process, device test) shudhu manush bodlay, `--as-human` diye.
- Branch prothi ekta in\_progress task.

## Claude Code diye kaj

Workflow ar rule [CLAUDE.md](CLAUDE.md) ar `.claude/rules/` e. Protita task: `Task: <ID>` bolo; Claude start, failing test, implement, check.sh, code-reviewer, done ei order e korbe.

`.claude/settings.json` secret file read, tracker file edit, ar main e push/force push deny kore; Stop hook `scripts/stop-check.sh` chalay. Eta GitHub branch protection er bikolpo na.
