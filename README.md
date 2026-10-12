# Framix repo skeleton

Photo ar video editor (Flutter UI + Rust engine). Naam Framix, bundle ID com.travela.framix, minimum iOS 17 ar Android 10, ABI arm64-v8a + x86\_64 (docs/adr/0001-product-basics.md).

## Ki ache

| Path | Ki |
| --- | --- |
| CLAUDE.md | Claude Code er main instruction: layout, command, rule, workflow, task tracking |
| .claude/rules/ | testing, architecture, performance (shob session); dart, rust, ffi, swift, kotlin (oi file e kaj korle) |
| .claude/agents/code-reviewer.md | Read-only reviewer subagent |
| .claude/settings.json | Secret file ar tracker file deny, main e push deny, Stop hook |
| scripts/check.sh | Shob check ek command e |
| scripts/task.py | Task tracker |
| tasks/tasks.json | 606 task er status |
| docs/plan.md | Master plan (ekhon theke eta-i master; onno copy purono hoye jabe) |
| docs/TASKS.md | Generated board |
| docs/architecture.md, toolchain.md, design-system.md | Claude er jonno chhoto English summary |

## Setup

1. Unzip, tarpor `git init -b main`, `git lfs install`, ar prothom commit.
2. GitHub e main branch protect koro (direct push ar force push bondho). settings.json er deny rule eka jothesto na.
3. Repo folder e `claude` chalao. Prothom bar folder trust koro, na hole Stop hook chole na.
4. `/memory` diye dekho CLAUDE.md, rules, ar import kora docs load hoyeche; path-scoped rule (dart.md ityadi) oi file khulle load hoy kina dekho.
5. `/permissions` diye deny rule gula active kina dekho.
6. Naam, minimum OS, ABI, bundle ID already decided (ADR 0001). Travela domain tomar na hole bundle ID prothom upload er age bodlao.

## Task tracking

Status tin ta: todo, in\_progress, done. Protita item er ID docs/plan.md e lekha (jemon `P1-012`).

```bash
python3 scripts/task.py next              # porer task er suggestion
python3 scripts/task.py start P1-001      # todo -> in_progress
python3 scripts/task.py note P1-001 "blocked: device lagbe"
python3 scripts/task.py done P1-001 --commit abc1234   # in_progress -> done
python3 scripts/task.py reopen P1-001 "regression"     # -> todo
python3 scripts/task.py add P1 "Fix seek drift on VFR clips" --tags Rust
python3 scripts/task.py list --status in_progress
```

- Script protibar plan.md er checkbox ar docs/TASKS.md board nijei update kore. Haate tick dio na.
- Owner "human" task (store, legal, process, device test) shudhu tumi bodlao: `--as-human` diye.
- AI-001 theke AI-010 ekhon in\_progress: skeleton e draft file ache. Review kore `python3 scripts/task.py done AI-001 --as-human` diye close koro.

## Prothom prompt (Claude Code)

```text
Read CLAUDE.md and docs/architecture.md. Run `python3 scripts/task.py next`
and propose a plan for the first task only. Do not write code until I approve.
```

Tarpor protita task: "Task: <ID> <title>" diye shuru koro; Claude CLAUDE.md er workflow mene start, test, check, review, done korbe.
