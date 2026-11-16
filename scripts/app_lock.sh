#!/usr/bin/env bash
# Runs a command under this checkout's app lock (app/.dart_tool/flutter_test.lock).
# Everything that writes generated files into app/ (gen-l10n, gen_ffi.sh) or reads them
# (flutter analyze, flutter test) takes it, so two checks in one checkout (the Stop hook next
# to a reviewer or a manual run) never see a generated file deleted or half-written.
# Re-entrant: a command already running under the lock (FRAMIX_APP_LOCK) runs directly.
# lockf on macOS, flock on Linux; -k keeps the lock file (lockf deletes it otherwise).
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 1
lock_file="$root/app/.dart_tool/flutter_test.lock"
[ "${FRAMIX_APP_LOCK:-}" = "$lock_file" ] && exec "$@"
mkdir -p "$root/app/.dart_tool"
export FRAMIX_APP_LOCK="$lock_file"
if command -v lockf >/dev/null 2>&1; then
  exec lockf -k "$lock_file" "$@"
elif command -v flock >/dev/null 2>&1; then
  exec flock "$lock_file" "$@"
else
  echo "⚠ app_lock.sh: no lockf or flock; running unlocked (concurrent runs may race)" >&2
  exec "$@"
fi
