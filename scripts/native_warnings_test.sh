#!/usr/bin/env bash
# Regression test (TC-015): scripts/native_warnings.sh must pass on a cold build (empty Gradle
# user home), whose -v log has upstream lines a warm build never prints, and must still fail on
# the same warnings from our own files. Runs a copy with a fake fvm whose `flutter build`
# prints a fixture log instead of building.
set -u
src="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/bin" "$tmp/app/android"
cp "$src/native_warnings.sh" "$src/flutter_sdk.sh" "$tmp/scripts/"
printf '{\n  "flutter": "1.2.3"\n}\n' >"$tmp/.fvmrc"
echo 'org.gradle.warning.mode=all' >"$tmp/app/android/gradle.properties"
cat >"$tmp/bin/fvm" <<EOF
#!/bin/sh
case "\$2" in
  --version) echo '  "frameworkVersion": "1.2.3",' ;;
  build) cat "$tmp/fixture.log" ;;
esac
EOF
chmod +x "$tmp/bin/fvm"
fail=0
# expect <name> <pass|fail> <log lines...>
expect() {
  local name=$1 want=$2 got=pass
  shift 2
  printf '%s\n' "$@" >"$tmp/fixture.log"
  PATH="$tmp/bin:/usr/bin:/bin" "$tmp/scripts/native_warnings.sh" >/dev/null 2>&1 || got=fail
  [ "$got" = "$want" ] || { echo "✗ native_warnings_test: $name: got $got, want $want" >&2; fail=1; }
}

gh=/Users/me/.gradle
jar=com.android.tools.build/transform-api/2.0.0-deprecated-use-gradle-api
cache=$gh/caches/modules-2/files-2.1/$jar/47f6c56527c42425742fa9b56ffd3fd80763fe03
maven=https://dl.google.com/dl/android/maven2/com/android/tools/build/transform-api/2.0.0-deprecated-use-gradle-api
plugin_kts=/Users/me/.pub-cache/hosted/pub.dev/package_info_plus-10.2.2/android/build.gradle.kts
deprecation=": 'fun Project.android(configure: Action<LibraryExtension>): Unit' is deprecated. Replaced by com.android.build.api.dsl.LibraryExtension."

expect "harness: clean log" pass ""
expect "cold-build upstream lines" pass \
  "[        ] Caching disabled for ExternalDependencyInstrumentingArtifactTransform: $cache/transform-api-2.0.0-deprecated-use-gradle-api.jar because:" \
  "[        ] Caching disabled for MergeInstrumentationAnalysisTransform: $cache/transform-api-2.0.0-deprecated-use-gradle-api.jar because:" \
  "[ +101 ms] Caching disabled for InstrumentationAnalysisTransform: $cache/transform-api-2.0.0-deprecated-use-gradle-api.jar because:" \
  "[        ] Downloading $maven/transform-api-2.0.0-deprecated-use-gradle-api.pom to $gh/.tmp/gradle_download2517546317397023967bin" \
  "[ +101 ms] Downloading $maven/transform-api-2.0.0-deprecated-use-gradle-api.jar to $gh/.tmp/gradle_download915979762424600016bin" \
  "[+2387 ms] w: file://$plugin_kts:47:1$deprecation"
expect "same deprecation in our own build file" fail \
  "[+2387 ms] w: file:///Users/me/Framix/app/android/app/build.gradle.kts:47:1$deprecation"
expect "warning that names the transform-api jar" fail \
  "[        ] w: $cache/transform-api-2.0.0-deprecated-use-gradle-api.jar: something is deprecated"

[ $fail -eq 0 ] && echo "✓ native_warnings_test"
