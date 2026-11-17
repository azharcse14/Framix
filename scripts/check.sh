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
# Here-string, not a pipe: under pipefail, grep -q exiting early gives the writer SIGPIPE (141).
touched() { [ $QUICK -eq 0 ] || grep -q "^$1" <<<"$changed"; }

# Task tracker consistency (fast, always)
run python3 scripts/task.py check

# Rust engine
if [ -f engine/Cargo.toml ] && touched engine/; then
  run cargo fmt --manifest-path engine/Cargo.toml --all -- --check
  run cargo clippy --manifest-path engine/Cargo.toml --workspace --all-targets -- -D warnings
  # Android-only code paths (cfg target_os = "android") are not built for the host.
  run cargo clippy --manifest-path engine/Cargo.toml -p framix_ffi --target aarch64-linux-android -- -D warnings
  run cargo test --manifest-path engine/Cargo.toml --workspace
fi

# Flutter app
if [ -f app/pubspec.yaml ] && { touched app/ || touched scripts/flutter_test.sh || touched scripts/flutter_sdk.sh || touched .fvmrc; }; then
  . scripts/flutter_sdk.sh || exit 1
  # Codegen and its readers hold this checkout's app lock (scripts/app_lock.sh), so a
  # concurrent check never reads a generated file while another rewrites it.
  run_in app ../scripts/app_lock.sh "${FLUTTER[@]}" gen-l10n
  run scripts/app_lock.sh git diff --exit-code -- app/lib/l10n/generated
  run_in app ../scripts/app_lock.sh "${FLUTTER[@]}" analyze
  # Hand-written Dart only; generated files keep their generator's layout. After analyze,
  # whose pub get gives the formatter the package language version. Same SDK as analyze.
  run_in app ../scripts/app_lock.sh "${DART[@]}" format --output=none --set-exit-if-changed \
    $(cd app && find lib test -name '*.dart' ! -name '*.g.dart' ! -path 'lib/l10n/generated/*' ! -path 'lib/core/engine/proto/*')
  run scripts/flutter_test.sh
fi

# Android instrumented tests must compile (they only run on a device or emulator).
if [ -f app/android/app/build.gradle.kts ] && { touched app/android/ || touched app/pubspec || touched .fvmrc ||
  touched scripts/android_test_build.sh || touched scripts/flutter_sdk.sh || touched scripts/app_lock.sh; }; then
  run scripts/android_test_build.sh
fi

# Generated FFI code must match its sources (header from engine/ffi, Dart from the header).
if touched engine/ || touched app/ || touched proto/; then
  run scripts/gen_ffi.sh
  run scripts/app_lock.sh git diff --exit-code -- engine/ffi/include app/lib/core/engine/engine_bindings.g.dart app/lib/core/engine/proto
fi

# Shell script regression tests
if touched scripts/; then
  run scripts/codegen_lock_test.sh
  run scripts/gen_ffi_failure_test.sh
  run scripts/gen_ffi_partial_test.sh
  run scripts/flutter_sdk_test.sh
  run scripts/gen_ffi_test.sh
  run scripts/native_warnings_test.sh
  run scripts/check_quick_test.sh
  # A Gradle build: in --quick mode only when the Android build script or its test changed.
  touched scripts/android_test_build && run scripts/android_test_build_test.sh
fi

# Protobuf contract
if [ -f proto/buf.yaml ] && touched proto/; then
  run_in proto buf lint
  # Compare with where this work started: the merge-base with main. On main itself (or a
  # branch with no commits yet) that is HEAD, so compare with HEAD~1, the previous main; that
  # covers HEAD's own commit plus any uncommitted edits. Comparing with HEAD would let a proto
  # change committed on main be checked against itself.
  proto_base=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null)
  if [ "$proto_base" = "$(git rev-parse HEAD)" ]; then
    proto_base=$(git rev-parse --verify --quiet HEAD~1)
  fi
  if [ -n "$proto_base" ] && git cat-file -e "$proto_base:proto/buf.yaml" 2>/dev/null; then
    proto_snap=$(mktemp -d)
    git archive "$proto_base" proto | tar -x -C "$proto_snap"
    run buf breaking proto --against "$proto_snap/proto"
    rm -rf "$proto_snap"
  else
    echo "⚠ buf breaking skipped: no base with proto/buf.yaml"
  fi
fi

if [ $fail -ne 0 ]; then echo "✗ checks failed" >&2; exit 1; fi
echo "✓ all checks passed"
