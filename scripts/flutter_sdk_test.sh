#!/usr/bin/env bash
# Regression test (TC-016, SYS-051): scripts/flutter_sdk.sh must fail when fvm is missing or its
# Flutter differs from .fvmrc (no silent fallback to another Flutter), and must clear the stale
# app/.dart_tool/hooks_runner whenever app/.dart_tool/version (written by the Flutter that last
# ran in app/) differs from the pin, under the app lock. Runs on a copy with a fake fvm.
set -u
src="$(cd "$(dirname "$0")" && pwd)/flutter_sdk.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/bin" "$tmp/app/.dart_tool/hooks_runner"
cp "$src" "${src%/*}/app_lock.sh" "$tmp/scripts/"
printf '{\n  "flutter": "1.2.3"\n}\n' >"$tmp/.fvmrc"
echo 1.2.2 >"$tmp/app/.dart_tool/version"
# A fake rm that records the app lock it runs under when it clears hooks_runner.
cat >"$tmp/bin/rm" <<EOF
#!/bin/sh
case "\$*" in *hooks_runner*) echo "\${FRAMIX_APP_LOCK:-unlocked}" >>"$tmp/rm.log" ;; esac
exec /bin/rm "\$@"
EOF
chmod +x "$tmp/bin/rm"
fail=0
gate() { PATH="$tmp/bin:/usr/bin:/bin" bash -c ". '$tmp/scripts/flutter_sdk.sh' && echo \"\${FLUTTER[*]}|\${DART[*]}\"" 2>/dev/null; }
expect() { [ "$2" = "$3" ] || { echo "✗ flutter_sdk_test: $1: got '$2', want '$3'" >&2; fail=1; }; }
hooks() { [ -d "$tmp/app/.dart_tool/hooks_runner" ] && echo kept || echo cleared; }

expect "fvm missing" "$(gate || echo FAIL)" FAIL
expect "hooks_runner kept when the gate fails" "$(hooks)" kept

fake_fvm() { printf '#!/bin/sh\necho "  \\"frameworkVersion\\": \\"%s\\","\n' "$1" >"$tmp/bin/fvm"; chmod +x "$tmp/bin/fvm"; }
fake_fvm 1.2.4
expect "version mismatch" "$(gate || echo FAIL)" FAIL

fake_fvm 1.2.3
expect "version match" "$(gate || echo FAIL)" "fvm flutter|fvm dart"
expect "hooks_runner cleared when built by another SDK" "$(hooks)" cleared
expect "hooks_runner cleared under the app lock" "$(cat "$tmp/rm.log" 2>/dev/null)" "$tmp/app/.dart_tool/flutter_test.lock"
# The pinned Flutter rebuilt it and rewrote version: keep it.
echo 1.2.3 >"$tmp/app/.dart_tool/version"
mkdir "$tmp/app/.dart_tool/hooks_runner"
gate >/dev/null
expect "hooks_runner kept when built by the pinned SDK" "$(hooks)" kept
# A bare flutter of another version rebuilt it after the pin was already seen: clear it again.
echo 1.2.9 >"$tmp/app/.dart_tool/version"
gate >/dev/null
expect "hooks_runner cleared after a rebuild by another SDK" "$(hooks)" cleared

# Review of SYS-051: version only changes on pub get, so also key on the SDK each hook was built
# with (hook.dependencies_hash_file.json lists <flutterRoot>/bin/cache/dart-sdk/version).
mkdir -p "$tmp/sdk/pin/bin/cache/dart-sdk" "$tmp/sdk/old/bin/cache/dart-sdk"
echo "3.13.5" >"$tmp/sdk/pin/bin/cache/dart-sdk/version"
echo "3.13.4" >"$tmp/sdk/old/bin/cache/dart-sdk/version"
ln -s "$tmp/sdk/pin" "$tmp/sdk/link"
printf '#!/bin/sh\necho "  \\"frameworkVersion\\": \\"1.2.3\\","\necho "  \\"flutterRoot\\": \\"%s\\","\n' "$tmp/sdk/pin" >"$tmp/bin/fvm"
echo 1.2.3 >"$tmp/app/.dart_tool/version"
hook_built_by() {
  mkdir -p "$tmp/app/.dart_tool/hooks_runner/framix/abc"
  printf '{"file_system":[{"path":"%s/bin/cache/dart-sdk/version","hash":1}],"environment":[]}' "$1" \
    >"$tmp/app/.dart_tool/hooks_runner/framix/abc/hook.dependencies_hash_file.json"
}
hook_built_by "$tmp/sdk/old"
gate >/dev/null
expect "hooks_runner cleared after a pin bump and pub get (built by the old SDK)" "$(hooks)" cleared
hook_built_by "$tmp/sdk/pin"
gate >/dev/null
expect "hooks_runner kept when built by the pinned SDK (hash file)" "$(hooks)" kept
hook_built_by "$tmp/sdk/link"
gate >/dev/null
expect "hooks_runner kept when built by the pinned SDK through a symlink" "$(hooks)" kept
hook_built_by "$tmp/sdk/gone"
gate >/dev/null
expect "hooks_runner cleared when built by a deleted SDK" "$(hooks)" cleared

[ $fail -eq 0 ] && echo "✓ flutter_sdk_test"
exit $fail
