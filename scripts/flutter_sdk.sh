# Sourced (not run) by every script that calls Flutter or Dart: sets FLUTTER=(fvm flutter) and
# DART=(fvm dart), or fails if fvm is missing or its Flutter differs from the .fvmrc pin.
# Never falls back to another Flutter on PATH (TC-016): fvm itself runs the PATH flutter when
# its SDK cache is broken, so the version is checked, not trusted.
# Install: brew tap btwld/fvm && brew install btwld/fvm/fvm && fvm install (in the repo root).
# `|| true`: callers run with `set -e`, which would otherwise exit here without the message below.
flutter_sdk_pin=$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' "$(dirname "${BASH_SOURCE[0]}")/../.fvmrc") || true
if ! command -v fvm >/dev/null 2>&1; then
  echo "✗ fvm not found; Flutter $flutter_sdk_pin is pinned in .fvmrc. Install: brew tap btwld/fvm && brew install btwld/fvm/fvm && fvm install" >&2
  return 1 2>/dev/null || exit 1
fi
flutter_sdk_machine=$(fvm flutter --version --machine 2>/dev/null) || true
flutter_sdk_actual=$(sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' <<<"$flutter_sdk_machine")
# The pinned SDK's bin, for tools that call bare `dart` themselves (protoc-gen-dart).
FLUTTER_SDK_BIN="$(sed -n 's/.*"flutterRoot": *"\([^"]*\)".*/\1/p' <<<"$flutter_sdk_machine")/bin"
if [ -z "$flutter_sdk_pin" ] || [ "$flutter_sdk_actual" != "$flutter_sdk_pin" ]; then
  echo "✗ fvm flutter is '${flutter_sdk_actual:-unknown}', .fvmrc pins '${flutter_sdk_pin:-unknown}'. Run: fvm install" >&2
  return 1 2>/dev/null || exit 1
fi
# app/.dart_tool/hooks_runner holds kernel snapshots of the SDK that built them; after an SDK
# switch `dart run` fails with "Invalid SDK hash". It is stale when app/.dart_tool/version
# (written by the last Flutter pub get in app/) differs from the pin, or when a hook's
# hook.dependencies_hash_file.json lists a <flutterRoot>/bin/cache/dart-sdk/version whose
# content differs from the pinned SDK's (compared by content, so a symlinked SDK path matches).
# Checked, then re-checked and cleared under the app lock so a locked run is never cut off.
# $1 = app/.dart_tool, $2 = pin, $3 = the pinned SDK's dart-sdk/version.
flutter_sdk_stale='{ [ -f "$1/version" ] && [ "$(cat "$1/version")" != "$2" ]; } ||
  ! grep -ho "\"[^\"]*/bin/cache/dart-sdk/version\"" "$1"/hooks_runner/*/*/hook.dependencies_hash_file.json 2>/dev/null |
    tr -d "\"" | while IFS= read -r v; do cmp -s "$v" "$3" || exit 1; done'
flutter_sdk_args=(sh "$(dirname "${BASH_SOURCE[0]}")/../app/.dart_tool" "$flutter_sdk_pin" "$FLUTTER_SDK_BIN/cache/dart-sdk/version")
if [ -d "${flutter_sdk_args[1]}/hooks_runner" ] && sh -c "$flutter_sdk_stale" "${flutter_sdk_args[@]}"; then
  "$(dirname "${BASH_SOURCE[0]}")/app_lock.sh" sh -c "if $flutter_sdk_stale; then rm -rf \"\$1/hooks_runner\"; fi" \
    "${flutter_sdk_args[@]}" || true
fi
FLUTTER=(fvm flutter)
DART=(fvm dart)
