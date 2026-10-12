#!/usr/bin/env bash
# Single entry point for every check. Used by the CLAUDE.md workflow, CI,
# the Stop hook, and the code-reviewer subagent, so the list lives here only.
# Usage: scripts/check.sh [--quick]   (--quick = only parts with changes)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1
fail=0

run() {
  echo "▶ $*"
  if ! "$@"; then echo "✗ failed: $*" >&2; fail=1; fi
}
run_in() {
  local dir=$1; shift
  echo "▶ ($dir) $*"
  if ! (cd "$dir" && "$@"); then echo "✗ failed in $dir: $*" >&2; fail=1; fi
}

changed=""
if [ $QUICK -eq 1 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  base=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo HEAD)
  changed=$({ git diff --name-only "$base" 2>/dev/null; git diff --name-only; git ls-files --others --exclude-standard; } | sort -u)
  if [ -z "$changed" ]; then echo "No changes; nothing to check."; exit 0; fi
fi
touched() { [ $QUICK -eq 0 ] || printf '%s\n' "$changed" | grep -q "^$1"; }

# Task tracker consistency (fast, always)
run python3 scripts/task.py check

# Rust engine
if [ -f engine/Cargo.toml ] && touched engine/; then
  run cargo fmt --manifest-path engine/Cargo.toml --all -- --check
  run cargo clippy --manifest-path engine/Cargo.toml --workspace --all-targets -- -D warnings
  run cargo test --manifest-path engine/Cargo.toml --workspace
fi

# Flutter app
if [ -f app/pubspec.yaml ] && touched app/; then
  if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi
  run_in app "${FLUTTER[@]}" analyze
  run_in app "${FLUTTER[@]}" test
fi

# Protobuf contract
if [ -f proto/buf.yaml ] && touched proto/; then
  run_in proto buf lint
  if git rev-parse --verify main >/dev/null 2>&1; then
    run buf breaking proto --against '.git#branch=main,subdir=proto'
  fi
fi

if [ $fail -ne 0 ]; then echo "✗ checks failed" >&2; exit 1; fi
echo "✓ all checks passed"
