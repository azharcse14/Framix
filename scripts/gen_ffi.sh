#!/usr/bin/env bash
# Regenerates every FFI artifact: C header (cbindgen), Dart bindings (ffigen), and the Dart
# Protobuf types (protoc + protoc_plugin). Rust Protobuf types are built by engine/app/build.rs.
# check.sh runs this and fails if any output differs from what is committed.
set -euo pipefail
cd "$(dirname "$0")/.."

CBINDGEN_VERSION=0.29.4
if [ "$(cbindgen --version 2>/dev/null)" != "cbindgen $CBINDGEN_VERSION" ]; then
  echo "need cbindgen $CBINDGEN_VERSION: cargo install cbindgen --version $CBINDGEN_VERSION --locked" >&2
  exit 1
fi
PROTOC_PLUGIN_VERSION=25.1.0
if ! dart pub global list 2>/dev/null | grep -qx "protoc_plugin $PROTOC_PLUGIN_VERSION"; then
  echo "need protoc_plugin $PROTOC_PLUGIN_VERSION: dart pub global activate protoc_plugin $PROTOC_PLUGIN_VERSION" >&2
  exit 1
fi
if command -v fvm >/dev/null 2>&1; then DART=(fvm dart); else DART=(dart); fi

cbindgen --quiet --config engine/ffi/cbindgen.toml --crate framix_ffi \
  --output engine/ffi/include/framix_engine.h engine/ffi
# A declaration ffigen can't bind is only reported as a warning and silently left out.
out=$(cd app && "${DART[@]}" run ffigen --config ffigen.yaml 2>&1)
# Allowed: the Engine handle is opaque on purpose, so it has no C definition.
if grep -E '\[(WARNING|SEVERE)\]' <<<"$out" | grep -v 'No definition found for declaration .*spelling: Engine,' >&2; then
  exit 1
fi

rm -rf app/lib/core/engine/proto && mkdir -p app/lib/core/engine/proto
PATH="$HOME/.pub-cache/bin:$PATH" protoc -I proto --dart_out=app/lib/core/engine/proto \
  proto/framix/v1/engine.proto
