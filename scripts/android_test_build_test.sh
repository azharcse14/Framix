#!/usr/bin/env bash
# Regression test (P1-133): scripts/android_test_build.sh must compile the Android instrumented
# tests (app/android/app/src/androidTest), so a broken one fails check.sh instead of breaking
# silently until someone runs it on a device. A Gradle init script adds a broken Kotlin file to
# the androidTest source set (the tree stays untouched); the build must fail on that file.
set -u
cd "$(dirname "$0")/.." || exit 1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/src"
echo 'class P1133Broken { val x: Int = "not an Int" }' >"$tmp/src/P1133Broken.kt"
cat >"$tmp/init.gradle" <<EOF
gradle.beforeProject { p ->
  if (p.path == ':app') p.pluginManager.withPlugin('com.android.application') {
    p.android.sourceSets.androidTest.java.srcDir('$tmp/src')
  }
}
EOF
if out=$(scripts/android_test_build.sh -I "$tmp/init.gradle" 2>&1); then
  echo "✗ android_test_build_test: build passed with a broken androidTest file" >&2
  exit 1
fi
if ! grep -q 'P1133Broken\.kt' <<<"$out"; then
  echo "✗ android_test_build_test: build failed, but not on the broken androidTest file:" >&2
  tail -30 <<<"$out" >&2
  exit 1
fi
echo "✓ android_test_build_test"
