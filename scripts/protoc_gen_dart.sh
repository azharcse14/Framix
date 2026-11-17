#!/bin/sh
# protoc-gen-dart for gen_ffi.sh, on the Dart first on PATH (gen_ffi puts the pinned SDK's bin
# there). Not the ~/.pub-cache/bin shim: that runs a snapshot named after whichever Dart last
# wrote the shim, so another Dart printed "Can't load Kernel binary: Invalid SDK hash." (SYS-057).
exec dart pub global run protoc_plugin:protoc_plugin "$@"
