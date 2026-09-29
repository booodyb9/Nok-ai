# NOK AI — 0.1.0 preview

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

The preview APK uses debug signing with release optimizations. Configure your own release keystore before distributing through an app store. GitHub Actions builds the Android preview APK on pushes to main. Download NOK-AI-preview-arm64 from the successful workflow run artifacts.

## Connect AI

Open Settings → AI provider. Choose Gemini, OpenAI, Claude, Qwen, DeepSeek, OpenRouter, Ollama, or Azure OpenAI. Enter a valid model, API key, and endpoint. Models shown are editable examples, not a guarantee of account access. Android stores the key in Flutter Secure Storage. Web keys remain in memory for the session and provider CORS policies may block web requests. This is a personal BYOK build, not a hosted service with a shared secret embedded in the app.

Photos and text attachments are sent only when a request is submitted. PDF works through compatible OpenAI/Claude/OpenRouter vision models; other PDF routes are explicitly rejected. DOC/DOCX parsing is not implemented. Past attachment bytes are not persisted. Web search opens a real browser; it does not fabricate in-app search results.

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
