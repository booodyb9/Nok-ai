---
name: android-apk-build
description: Build and verify Android APKs with Gradle and GitHub Actions without leaking secrets or claiming unverified artifacts.
---

# Android APK Build

1. Inspect the repository, wrapper, JDK requirement, SDK configuration, flavors, signing config, and workflow files.
2. Identify the existing framework and use its current build path.
3. Never commit secrets or signing materials. Use GitHub Actions secrets for protected signing where appropriate.
4. Prefer a reproducible debug APK workflow first; do not change release signing without approval.
5. Run the appropriate build command only when its wrapper/configuration exists.
6. Inspect workflow logs and confirm the expected APK path exists before claiming success.
7. Report build status, workflow URL, artifact filename, and device tests not performed.
