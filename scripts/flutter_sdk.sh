# Sourced (not run) by every script that calls Flutter or Dart: sets FLUTTER=(fvm flutter) and
# DART=(fvm dart), or fails if fvm is missing or its Flutter differs from the .fvmrc pin.
# Never falls back to another Flutter on PATH (TC-016): fvm itself runs the PATH flutter when
# its SDK cache is broken, so the version is checked, not trusted.
# Install: brew tap btwld/fvm && brew install btwld/fvm/fvm && fvm install (in the repo root).
flutter_sdk_pin=$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' "$(dirname "${BASH_SOURCE[0]}")/../.fvmrc")
if ! command -v fvm >/dev/null 2>&1; then
  echo "✗ fvm not found; Flutter $flutter_sdk_pin is pinned in .fvmrc. Install: brew tap btwld/fvm && brew install btwld/fvm/fvm && fvm install" >&2
  return 1 2>/dev/null || exit 1
fi
flutter_sdk_actual=$(fvm flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')
if [ -z "$flutter_sdk_pin" ] || [ "$flutter_sdk_actual" != "$flutter_sdk_pin" ]; then
  echo "✗ fvm flutter is '${flutter_sdk_actual:-unknown}', .fvmrc pins '${flutter_sdk_pin:-unknown}'. Run: fvm install" >&2
  return 1 2>/dev/null || exit 1
fi
# app/.dart_tool/hooks_runner holds kernel snapshots of the SDK that built them; after an SDK
# switch `dart run` fails with "Invalid SDK hash". Clear it once per pin change (stamp file).
flutter_sdk_stamp="$(dirname "${BASH_SOURCE[0]}")/../app/.dart_tool/flutter_sdk.version"
if [ -d "${flutter_sdk_stamp%/*}" ] && [ "$(cat "$flutter_sdk_stamp" 2>/dev/null)" != "$flutter_sdk_pin" ]; then
  rm -rf "${flutter_sdk_stamp%/*}/hooks_runner"
  echo "$flutter_sdk_pin" >"$flutter_sdk_stamp"
fi
FLUTTER=(fvm flutter)
DART=(fvm dart)
