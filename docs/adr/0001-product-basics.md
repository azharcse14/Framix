# 0001. Product basics: name, bundle ID, minimum OS, Android ABIs
Status: accepted
Date: 2026-10-12
Tasks: REL-017, REL-019, REL-022, PLAT-001, TC-008, GOT-001

## Context
The bundle ID cannot change after the first store upload. Minimum OS versions and Android ABIs decide how much fallback code, how many native builds, and how big a test matrix the project carries. The plan proposed iOS 17 and Android 9 and left ABIs open.

## Decision
- **Name:** Framix. Store name "Framix: Photo & Video Editor". Project file extension `.framix`.
- **Bundle ID / applicationId:** `com.travela.framix` (`flutter create --org com.travela --project-name framix --platforms ios,android`).
- **Minimum iOS 17.0:** Vision subject lift (foreground instance mask) without a fallback path; iOS 17 runs on the same iPhones as iOS 18 (XS/XR and later).
- **Minimum Android 10 (API 29)**, raised from the proposed Android 9:
  - API 29 adds `MediaCodecInfo.isHardwareAccelerated` / `isSoftwareOnly` and video performance points, which the export pre-flight and device tiers rely on.
  - Scoped storage everywhere: one MediaStore code path, no `WRITE_EXTERNAL_STORAGE` branch.
  - 64-bit devices that launched with Android 10 ship Vulkan 1.1, so more devices take the Vulkan path. The GLES fallback is still required for upgraded and low-end phones.
  - Android 9 phones are the oldest and weakest in the market and would mostly run in limited mode anyway.
- **Android ABIs:** ship `arm64-v8a` and `x86_64` (emulator, ChromeOS); App Bundle splits keep phone downloads unaffected. No `armeabi-v7a`.
  - Removes a full extra native build and test target.
  - 32-bit-only phones cannot run a multi-track editor well.
  - Flutter builds use `--target-platform android-arm64,android-x64`, with matching `abiFilters`.

## Consequences
- Some 2 GB Android Go phones run a 32-bit OS on a 64-bit chip and will not see the app. Accepted; revisit only if install data shows a real gap. Adding an ABI later is possible; removing one is not.
- The P1-004 low-end device test confirms the Android minimum; change it only with a new ADR.
- "Framix" still needs a trademark search before launch (LEG-015). Confusion risk with the "Filmix" video editor is noted in REL-022.
- The bundle ID assumes Travela owns the travela domain. If not, change it before the first store upload.
