#!/usr/bin/env bash
# Builds the Android instrumented tests (app/android/app/src/androidTest) into the debug test
# APK, so check.sh catches a broken one without a device or emulator (P1-133). Extra arguments
# go to Gradle. ABIs as in docs/toolchain.md. Runs under the app lock: Flutter rewrites
# app/.dart_tool and the generated plugin files.
set -euo pipefail
cd "$(dirname "$0")/../app"
. ../scripts/flutter_sdk.sh
# gradlew and local.properties are generated (gitignored); --config-only writes them, no build.
../scripts/app_lock.sh "${FLUTTER[@]}" build apk --config-only
cd android
../../scripts/app_lock.sh ./gradlew app:assembleDebugAndroidTest \
  -Ptarget-platform=android-arm64,android-x64 "$@"
