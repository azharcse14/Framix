#!/usr/bin/env bash
# Regression test (TC-016): scripts/flutter_sdk.sh must fail when fvm is missing or its Flutter
# differs from .fvmrc (no silent fallback to another Flutter), and must clear the stale
# app/.dart_tool/hooks_runner once after a pin change. Runs on a copy with a fake fvm.
set -u
src="$(cd "$(dirname "$0")" && pwd)/flutter_sdk.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/bin" "$tmp/app/.dart_tool/hooks_runner"
cp "$src" "$tmp/scripts/"
printf '{\n  "flutter": "1.2.3"\n}\n' >"$tmp/.fvmrc"
fail=0
gate() { PATH="$tmp/bin:/usr/bin:/bin" bash -c ". '$tmp/scripts/flutter_sdk.sh' && echo \"\${FLUTTER[*]}|\${DART[*]}\"" 2>/dev/null; }
expect() { [ "$2" = "$3" ] || { echo "✗ flutter_sdk_test: $1: got '$2', want '$3'" >&2; fail=1; }; }

expect "fvm missing" "$(gate || echo FAIL)" FAIL
expect "hooks_runner kept when the gate fails" "$([ -d "$tmp/app/.dart_tool/hooks_runner" ] && echo kept)" kept

fake_fvm() { printf '#!/bin/sh\necho "  \\"frameworkVersion\\": \\"%s\\","\n' "$1" >"$tmp/bin/fvm"; chmod +x "$tmp/bin/fvm"; }
fake_fvm 1.2.4
expect "version mismatch" "$(gate || echo FAIL)" FAIL

fake_fvm 1.2.3
expect "version match" "$(gate || echo FAIL)" "fvm flutter|fvm dart"
expect "hooks_runner cleared on pin change" "$([ -d "$tmp/app/.dart_tool/hooks_runner" ] && echo kept || echo cleared)" cleared
mkdir "$tmp/app/.dart_tool/hooks_runner"
gate >/dev/null
expect "hooks_runner kept on same pin" "$([ -d "$tmp/app/.dart_tool/hooks_runner" ] && echo kept)" kept

[ $fail -eq 0 ] && echo "✓ flutter_sdk_test"
exit $fail
