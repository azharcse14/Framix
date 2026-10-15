#!/usr/bin/env bash
# Warning zero for the platform builds (TC-006): builds iOS (simulator) and Android debug and
# fails on any Xcode or Gradle warning not listed below. Slow (minutes), so check.sh skips it;
# run it after touching app/ios, app/android, native/, or a toolchain version.
set -euo pipefail
cd "$(dirname "$0")/../app"
if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi

# Known upstream warnings, one regex per line, each with its reason. Remove a line once the
# upstream fix lands.
ALLOWED='
# Flutter tool scheme script reads Xcode env it does not know (Flutter 3.47).
unknown environment variable SWIFT_DEBUG_INFORMATION_(FORMAT|VERSION)
# Xcode prints this for every app without AppIntents.
Metadata extraction skipped\. No AppIntents\.framework dependency found
# Flutter 3.47 Gradle plugin needs the old DSL and KGP: newDsl=false, builtInKotlin=false,
# org.jetbrains.kotlin.android, and the old android {} accessor in app/build.gradle.kts.
android\.(newDsl|builtInKotlin)=false. is deprecated
Deprecated .org\.jetbrains\.kotlin\.android. plugin usage
build\.gradle\.kts:7:1: .fun Project\.android.* is deprecated
suppressAgpWarnings=DEPRECATED_DSL
# Flutter Gradle plugin source and its old variant API (flutter_tools/gradle).
flutter_tools/gradle/src/main/kotlin/.* is deprecated
API .(applicationVariants|testVariants|unitTestVariants). is obsolete
# Gradle native-platform on a newer JVM. Only the rubygrapefruit line names the caller; the
# other three are generic JVM lines it triggers, so recheck them on the pinned JDK 21.
System::load has been called by net\.rubygrapefruit
--enable-native-access=ALL-UNNAMED
Restricted methods will be blocked in a future release
A restricted method in java\.lang\.System has been called
# AGP CMake log line; ANDROID_NDK_HOME is not used (ndkVersion is pinned).
Not considering ANDROID_NDK_HOME
'
allowed=$(grep -v -e '^#' -e '^$' <<<"$ALLOWED")

# Gradle lists each deprecation only with warning mode "all" (app/android/gradle.properties);
# otherwise one summary line hides them, and that line is never allowed.
grep -qx 'org.gradle.warning.mode=all' android/gradle.properties ||
  { echo "app/android/gradle.properties needs org.gradle.warning.mode=all" >&2; exit 1; }

log=$(mktemp)
build() {
  echo "▶ (app) flutter build $*"
  "${FLUTTER[@]}" build "$@" -v >>"$log" 2>&1 ||
    { tail -100 "$log" >&2; echo "✗ build failed; full log: $log" >&2; exit 1; }
}
build ios --simulator --debug
build apk --debug --target-platform android-arm64,android-x64

# Real diagnostics only: skip Xcode's echoed build settings (export FOO_WARN_...=YES).
diagnostics=$(grep -E '(^|[^A-Za-z_])([Ww]arning:|WARNING:|\bw: |[Dd]eprecated)' "$log" |
  grep -vE '^\s*(\[[^]]*\]\s*)?export |^\s*\[[^]]*\]\s+[A-Z_]+ = ' || true)
# grep -v exits 1 when every line is allowed (fine) and 2 on a bad allowlist regex (fail).
status=0
found=$(grep -vE -f <(printf '%s\n' "$allowed") <<<"$diagnostics" | sort -u) || status=$?
[ "$status" -le 1 ] || { echo "allowlist regex error" >&2; exit 1; }
rm -f "$log"
if [ -n "$found" ]; then
  echo "✗ new platform build warnings:" >&2
  echo "$found" >&2
  exit 1
fi
echo "✓ no new platform build warnings"
