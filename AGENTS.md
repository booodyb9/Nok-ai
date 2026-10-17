# Android AI Project Rules

- Inspect project structure, Gradle wrapper, Android Gradle Plugin, Kotlin, SDK levels, and Git status before edits.
- Preserve architecture, UI, permissions, and working features unless requested.
- Never claim an APK exists unless a successful build artifact is available and verified.
- Use reproducible GitHub Actions builds when configured; report the exact workflow and artifact result.
- Never commit signing keys, API keys, Firebase service-account files, local.properties, or secrets.
- Accessibility services, screen overlays, camera, microphone, and screen capture require transparent user consent and platform-compliant permissions.
- Do not hardcode private API keys in the Android client.
- Run available tests, lint, and build tasks. Distinguish compilation from device testing.
- Do not publish releases or change signing settings without approval.
