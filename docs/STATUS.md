# NOK 0.1.0 preview — 2026-09-28

## Verified
- Flutter 3.47.5 dependency resolution completed; lockfile included.
- `flutter analyze --no-pub`: no issues found.
- 9 original automated tests passed: Arabic layouts at 360/390/430 px, navigation, 140% English text, insecure endpoint rejection, provider image payloads, Arabic conversation restoration, and memory exclusion.
- Real Flutter-rendered home screenshot inspected, including robot, font and icons.
- Flutter release web compilation succeeded.

## Implemented but not device/live-service tested
- Streaming AI via eight configurable providers; secure Android key storage.
- Speech recognition and sentence-queued TTS.
- Camera preview and serial frame analysis.
- Android accessibility reading and highlighting service.
- Firebase auth and manual backup/restore code and access rules.

## Blocked / not complete
- APK build is blocked during Gradle plugin resolution (`org.gradle.kotlin.kotlin-dsl:6.4.2`). No installable APK has been produced. Native Kotlin code has not completed compilation.
- No physical-device tests, live AI-provider tests, or Firebase deployment. Provider credentials and Firebase configuration are required.
- Visual screen OCR/AI reasoning, automatic screen actions, Firebase Functions gateway, realtime cloud synchronization, cloud attachment storage, DOCX parsing, and document export remain pending.
- Web is a functional preview with browser-specific camera/speech/CORS limitations; it does not provide Android screen access.
- Production signing and distribution have not been configured.

## Settings verification update — 2026-09-29
Flutter analyze: no issues. All 17 automated tests passed. Web release build succeeded. See DEVICE-CHECK.md for repairs, mocked-platform coverage, and remaining device acceptance checks.

## Provider diagnostics update — 2026-09-29
- OpenAI uses `max_completion_tokens`; complete API endpoint URLs no longer get a duplicated path.
- OpenAI/OpenRouter credentials are restricted to their official HTTPS endpoints. OpenRouter defaults to `openrouter/free` when selected.
- Provider settings include a real small streaming connection test, separate from saving. It sends no chat history or memory, discloses potential credit usage, and requires text before reporting success.
- HTTP and streaming errors show bounded structured provider details with the current key and common credential patterns redacted. Authentication, credits, quota, rate limits, and request errors are distinguished.
- Static analysis passed; all 26 automated tests passed, including nine mocked HTTP tests. No real provider key was supplied or used, so the reported account-specific HTTP 400 is not yet confirmed resolved.
- The user authorized GitHub upload and APK build on 2026-09-29; remote build results are pending. No key is embedded in source or the web build.
- Flutter release web build succeeded for this update.
