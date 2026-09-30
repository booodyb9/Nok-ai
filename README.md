# NOK AI — 0.1.2 preview

Arabic/English Flutter Android app, built directly in Work. The robot is integrated into the home background. Android package: `app.nok.nok_ai`, minimum Android 8 (API 26).

## Run and build

Use Flutter 3.47.5, Java 17 and Android SDK 36. Android NDK 28.2.13676358 is used by Flutter.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release --target-platform android-arm64
flutter build web
```

GitHub Actions builds ARM64 APKs on pushes to main. Persistent signing is supported through two repository secrets (`NOK_KEYSTORE_BASE64`, `NOK_KEYSTORE_PASSWORD`). Without them, the artifact is an intermediate debug-signed preview that must be signed with the retained NOK key before distribution. The two repository secrets are now configured. GitHub run 36676611419 produced a persistently signed 0.1.2 APK whose certificate matches the earlier locally signed 0.1.2 delivery. See `docs/SIGNING.md`. Earlier temporary preview signatures cannot be recovered; those installations cannot be updated in place with the new key.

## Connect AI

Open Settings → AI provider. Choose Gemini, OpenAI, Claude, Qwen, DeepSeek, OpenRouter, Ollama, or Azure OpenAI. Enter your API key and endpoint. Automatic model selection is enabled by default, including for existing configurations: Save or Test connection discovers current chat models from the provider catalog. Refresh automatic selection bypasses the ten-minute in-memory cache. Turn off automatic selection to enter a model manually. Catalog visibility is not a guarantee of account access or credits. Android stores the key in Flutter Secure Storage. Web keys remain in memory for the session and provider CORS policies may block web requests. This is a personal BYOK build, not a hosted service with a shared secret embedded in the app.

Discovery supports Gemini and Claude native model catalogs, OpenAI-compatible catalogs for OpenAI, Qwen, DeepSeek and installed Ollama models, and OpenRouter's account-filtered catalog. Azure extracts the deployment name from the full deployment URL; a key alone cannot supply that URL. Catalogs blocked by regional API support or account permissions require manual selection. OpenRouter prefers free candidates when present and never falls back from that free list to paid models. Image/PDF filtering uses provider metadata and model-family hints; manual selection remains available for unrecognized models and Azure attachment capabilities.

Temporary generation failures (500/502/503/504/529) receive at most three attempts with bounded backoff, with an alternative model on the final automatic attempt if available. A missing model can trigger an immediate alternative. Authentication, credit and rate-limit failures do not trigger model switching; partial responses are never replayed. Discovery errors are shown without fabricated fallback names. A successful catalog fetch is distinct from a successful connection test, which requires a text response. Provider outages and account billing issues cannot be resolved by model selection alone.

Photos and text attachments are sent only when a request is submitted. PDF works through compatible OpenAI/Claude/OpenRouter vision models; other PDF routes are explicitly rejected. DOC/DOCX parsing is not implemented. Past attachment bytes are not persisted. Web search opens a real browser; it does not fabricate in-app search results.

## Local chat backup

Settings → Chat backup file exports or restores a NOK JSON file without Firebase or internet. Backups contain chat text and attachment names, excluding provider keys, attachment bytes, preferences and memory. They are unencrypted: store them privately. Restore previews the chat count and asks before merging; existing IDs win and no existing conversation is deleted. Files are validated before persistence, with limits of 10 MB and 60 total conversations. Invalid/oversized backups and imports during a response are rejected. Earlier app versions do not have this export screen; installing this version cannot recover chats lost by uninstalling an older version.

## Firebase (optional; not connected)

Copy `config.example.json` to `config.local.json` and fill in your Firebase app configuration. Enable email/password authentication. Deploy the included Firestore rules to your own project, then:

```sh
flutter run --dart-define-from-file=config.local.json
flutter build apk --release --dart-define-from-file=config.local.json
```

Account sign-in, registration, password reset, manual backup and restore are coded. Firebase project resources and credentials have not been provided or deployed. Automatic realtime sync, Firebase Functions AI gateway and cloud attachment storage remain pending. Storage rules are included for future use, not a claim of active storage integration.

## Android screen guide

Enable NOK in Android Accessibility settings using the in-app Screen Guide page. The floating panel reads accessible text locally, supports automatic text updates and highlights the next element. No screen contents are sent to the network; password nodes are skipped. Image-only text, protected windows and visual AI reasoning are not supported yet. The service does not execute taps. Closing the panel stops reading until reopened.

## Camera and voice

Camera preview and repeated cloud frame analysis are coded, with one request at a time and a four-second gap after each response. This is repeated analysis, not a realtime video model. Permission denial has a visible error. Leaving the app stops camera/voice work. Arabic recognition/TTS requires language support on the phone. Chat TTS queues sentences as streaming responses arrive. Recognition allows review before send.

## Status

See `docs/STATUS.md` for actual build/test results and remaining work. A build is not evidence of physical-device testing.
