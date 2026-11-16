#!/usr/bin/env bash
# `flutter test` for app/ under the per-checkout app lock (scripts/app_lock.sh). Use this instead
# of a bare `flutter test`; check.sh calls it too. Arguments pass through (e.g.
# scripts/flutter_test.sh test/foo_test.dart).
# Every `flutter test` empties app/build/native_assets/macos, then copies, install_name_tools
# and codesigns libframix_ffi.dylib there, with no lock. Two runs in one checkout (e.g. the
# Stop hook's check.sh next to a manual one) race: one deletes the dylib while the other
# signs it ("Failed to code sign" / "install_name_tool: can't open file"). After a Rust change
# both wait on the same hook build and then install at the same moment, so it shows up most
# then. The lock also keeps it off generated files that codegen is rewriting.
set -u
cd "$(dirname "$0")/../app" || exit 1
if command -v fvm >/dev/null 2>&1; then flutter=(fvm flutter); else flutter=(flutter); fi
exec ../scripts/app_lock.sh "${flutter[@]}" test "$@"
