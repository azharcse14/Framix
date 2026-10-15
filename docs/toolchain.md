# Toolchain (latest stable, October 2026)

Pin everything; upgrade at the first patch 1-2 weeks after a major release; new dependency versions only once they are 14 days old. Re-check versions on the day the project starts. Details and sources: docs/plan.md (Toolchain ar version).

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter | 3.47.x (Dart 3.13), pinned with FVM | New code uses material_ui / cupertino_ui packages; pin their versions |
| Rust | 1.99.0, edition 2024, rust-toolchain.toml | 6-week releases; take patch releases |
| Xcode / iOS SDK | Xcode 27.1 (iOS 27.1 SDK) | Deployment target 15+ for Runner and every pod (Podfile post_install); UIScene life cycle required |
| Swift | 6.4 | Swift 6 language mode, strict concurrency |
| Android | compileSdk 37, targetSdk 36 (Play minimum), test 37 before raising | 16 KB page alignment for every .so |
| Android Gradle Plugin | The version Flutter supports (latest is 9.4.0) | AGP 9 built-in Kotlin; Flutter may need android.newDsl=false; check every plugin |
| Gradle / JDK | Gradle 9.6.0, JDK 21 | |
| Android NDK | r28c (28.2), pinned explicitly | 16 KB alignment default |
| Minimum OS | iOS 17.0, Android 10 (API 29) | docs/adr/0001-product-basics.md; confirmed by the low-end device test (P1-004) |
| Android ABIs | arm64-v8a, x86_64 | No armeabi-v7a; build with --target-platform android-arm64,android-x64 |
| FFI codegen | cbindgen 0.29.4 (`cargo install --locked`), ffigen 22.0.0 (dev dependency), protoc 36.2, protoc_plugin 25.1.0 (`dart pub global activate`), prost-build 0.14.4 + protox 0.9.1 (Rust build deps), buf 1.74.0 | Pinned in scripts/gen_ffi.sh, app/pubspec.yaml, engine/app/Cargo.toml; check.sh fails on stale generated code |
| Security audit | cargo-audit 0.22.2 (`cargo install --locked`) | `scripts/audit.sh`: cargo audit (fails on a vulnerability) + `dart pub outdated` (report); needs network, not in check.sh |

## Policy
- Lock files committed (Cargo.lock, pubspec.lock).
- Renovate or Dependabot weekly, with a 14-day minimum release age.
- Zero warnings: dart analyze, cargo clippy -D warnings, Xcode and Gradle deprecations.
- Before any upgrade, check the compatibility matrix: Flutter, AGP, Kotlin, plugins, Xcode.
- If an API you know looks different here, trust this file and the official docs over memory.
