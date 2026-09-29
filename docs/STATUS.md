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
- Android release preview now builds successfully on GitHub Actions, including native Kotlin compilation and release lint. Local Gradle resolution had previously blocked the build.
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
- The user authorized GitHub upload and APK build on 2026-09-29; remote build succeeded (run 36606847918). No key is embedded in source or the web build.
- Flutter release web build succeeded for this update.

## Android APK — 2026-09-29
- Source commit: `dae8a2af570ee3e6af9413f4d5d10b5ec59a6772`.
- Workflow: https://github.com/booodyb9/Nok-ai/actions/runs/36606847918 — succeeded.
- 26 tests and static analysis passed on GitHub. Fixed the release lint error by explicitly setting includeSubdomains=false for all three loopback/local domains.
- APK: ARM64, release optimizations, debug-signed preview; 24.5 MB reported by Flutter.
- Artifact archive SHA-256: `b8432aea57cca29842122334580389ff4c57db8792478872c0f7d9c59e511f68`.
- APK SHA-256: `d681a1dda5faaf4f0a0157fa56baae683089f48e8e48135968e927349c64fa35`.
- Downloaded artifact integrity and APK ZIP contents verified. Installation, voice/camera/accessibility on a physical phone, and live API calls are still unverified.

## Automatic model selection — 0.1.1+2
- Automatic selection is enabled for new and migrated configurations, with a manual override. Provider settings discover models on save/test or explicit refresh, not while typing credentials.
- Gemini/Claude pagination, OpenAI/Qwen/DeepSeek compatible catalogs, OpenRouter account-filtered catalog and installed Ollama models are supported. Azure extracts a deployment from its complete endpoint URL. Catalog support and account access still vary; manual mode is available.
- Selection filters chat models and attachment capabilities, caches for ten minutes per provider/endpoint/key, and prefers free OpenRouter candidates when available.
- Generation retries are bounded to three attempts for temporary server errors. Missing models may fall back; authentication/credits/rate limits do not. Partial responses are never replayed; cancellation stops retries.
- Local Flutter analysis: no issues. All 43 automated tests passed, including 15 model-discovery/retry tests and two settings UI tests. HTTP calls and platform services in tests are mocked; no live provider key was supplied.
- Version bumped to 0.1.1+2. Updated Android build pending the workflow for this source commit. Previous build results above refer to 0.1.0, not this update.
