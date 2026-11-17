#!/usr/bin/env bash
# Regenerates every FFI artifact: C header (cbindgen), Dart bindings (ffigen), and the Dart
# Protobuf types (protoc + protoc_plugin). Rust Protobuf types are built by engine/app/build.rs.
# check.sh runs this and fails if any output differs from what is committed.
set -euo pipefail
cd "$(dirname "$0")/.."
# It deletes and rewrites generated files in app/, so it runs under the app lock that flutter
# analyze/test take (scripts/app_lock.sh); otherwise they can read a file that is gone.
[ -n "${FRAMIX_APP_LOCK:-}" ] || exec scripts/app_lock.sh scripts/gen_ffi.sh "$@"

CBINDGEN_VERSION=0.29.4
if [ "$(cbindgen --version 2>/dev/null)" != "cbindgen $CBINDGEN_VERSION" ]; then
  echo "need cbindgen $CBINDGEN_VERSION: cargo install cbindgen --version $CBINDGEN_VERSION --locked" >&2
  exit 1
fi
PROTOC_VERSION=36.2
if [ "$(protoc --version 2>/dev/null)" != "libprotoc $PROTOC_VERSION" ]; then
  echo "need protoc $PROTOC_VERSION (brew install protobuf)" >&2
  exit 1
fi
PROTOC_PLUGIN_VERSION=25.1.0
. scripts/flutter_sdk.sh
# Here-string, not a pipe: under pipefail, grep -q exiting early gives the writer SIGPIPE (141).
if ! grep -qx "protoc_plugin $PROTOC_PLUGIN_VERSION" <<<"$("${DART[@]}" pub global list 2>/dev/null)"; then
  echo "need protoc_plugin $PROTOC_PLUGIN_VERSION: dart pub global activate protoc_plugin $PROTOC_PLUGIN_VERSION" >&2
  exit 1
fi

cbindgen --quiet --config engine/ffi/cbindgen.toml --crate framix_ffi \
  --output engine/ffi/include/framix_engine.h engine/ffi
# A declaration ffigen can't bind is only reported as a warning and silently left out.
out=$(cd app && "${DART[@]}" run ffigen --config ffigen.yaml 2>&1)
# Allowed: the Engine handle is opaque on purpose, so it has no C definition.
if grep -E '\[(WARNING|SEVERE)\]' <<<"$out" | grep -v 'No definition found for declaration .*spelling: Engine,' >&2; then
  exit 1
fi

# Into a temp dir, swapped in only on success: a failed protoc (SYS-059) must not leave the
# committed proto files deleted. Same filesystem, so mv is a rename.
proto_tmp=$(mktemp -d app/.dart_tool/proto.XXXXXX)
trap 'rm -rf "$proto_tmp"' EXIT
PATH="$FLUTTER_SDK_BIN:$HOME/.pub-cache/bin:$PATH" protoc -I proto --dart_out="$proto_tmp" \
  proto/framix/v1/engine.proto
chmod 755 "$proto_tmp"
rm -rf app/lib/core/engine/proto && mv "$proto_tmp" app/lib/core/engine/proto
