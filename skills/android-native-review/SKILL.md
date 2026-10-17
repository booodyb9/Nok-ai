---
name: android-native-review
description: Review Android Kotlin/Compose architecture, permissions, performance, accessibility, and UI regressions before changing code.
---

# Android Native Review

1. Identify Kotlin/Java, Compose/XML UI, architecture, DI, persistence, and min/target SDK from repository files.
2. Trace the relevant flow before editing; preserve current screens and navigation.
3. Review lifecycle-aware state collection, coroutine dispatchers, error/loading/empty states, and configuration changes where applicable.
4. Check permission rationale and consent for camera, microphone, notifications, overlays, and accessibility services.
5. Avoid unnecessary dependencies and APIs incompatible with minSdk.
6. Run available unit tests, lint, and build tasks; record exact results.
7. Report findings with file paths and severity. Audit-only requests must not modify files.
