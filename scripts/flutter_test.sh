#!/usr/bin/env bash
# `flutter test` for app/ under a per-checkout lock. Use this instead of a bare `flutter test`;
# check.sh calls it too. Arguments pass through (e.g. scripts/flutter_test.sh test/foo_test.dart).
# Every `flutter test` empties app/build/native_assets/macos, then copies, install_name_tools
# and codesigns libframix_ffi.dylib there, with no lock. Two runs in one checkout (e.g. the
# Stop hook's check.sh next to a manual one) race: one deletes the dylib while the other
# signs it ("Failed to code sign" / "install_name_tool: can't open file"). After a Rust change
# both wait on the same hook build and then install at the same moment, so it shows up most
# then. Hold the lock around the run (lockf on macOS, flock on Linux).
set -u
cd "$(dirname "$0")/../app" || exit 1
if command -v fvm >/dev/null 2>&1; then flutter=(fvm flutter); else flutter=(flutter); fi
mkdir -p .dart_tool
lock_file="$PWD/.dart_tool/flutter_test.lock"
# -k keeps the lock file; without it lockf deletes the file on exit.
if command -v lockf >/dev/null 2>&1; then
  exec lockf -k "$lock_file" "${flutter[@]}" test "$@"
elif command -v flock >/dev/null 2>&1; then
  exec flock "$lock_file" "${flutter[@]}" test "$@"
else
  echo "⚠ flutter_test.sh: no lockf or flock; running unlocked (concurrent runs may race)" >&2
  exec "${flutter[@]}" test "$@"
fi
