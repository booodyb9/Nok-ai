# Camera, voice and screen-guide verification — 2026-09-29

## Scope
Source review and automated Flutter tests with mocked platform services. These tests do not establish that a real microphone, camera or Android accessibility service works on a physical device. No AI credentials or camera images were sent to a live provider during verification.

## Repairs
- Voice: removed the Android-only queue call from other platforms; serial speech now waits for completion, short sentences start promptly, and stopping discards queued speech. Missing speech language is reported rather than silently using another language.
- Camera: denied/unavailable cameras show a retry action and disabled analysis buttons; asynchronous discovery is checked against disposal; stale requests cannot clear a newer request's busy state. Repeated analysis waits for speech before its next frame and stops on leaving the page/backgrounding.
- Android screen guide: language, volume and speed are saved to native preferences; changes synchronize from app settings. Auto-reading can restart on the same screen, unavailable screen roots clear stale text/highlights, and the panel has a separate stop-speech button. Disabled native service returns an error.
- Speech callbacks ignore results after the chat widget is disposed.

## Automated cases
- Five voice cases: portable preparation; Android queue mode; short sentence dispatch; stop drops pending sentences; camera narration waits for playback.
- Three camera/screen cases: camera denial and retry; unsupported screen-guide platform; native bridge receives language/rate/volume.
- Existing nine engine/layout cases retained.

## Device acceptance still required
1. Build/install Android APK and enable NOK in Android Accessibility settings. Verify panel appears in another app, next-element highlight matches the screen, and close/stop work.
2. Check Arabic/English screen reading, speed and volume changes, automatic reading across navigation, and password-field exclusion. Image-only text is not supported by this service.
3. Deny camera access; confirm retry. Then grant permission and verify both available lenses, one-frame analysis and repeated analysis with a vision-capable provider. Background/close the page and confirm camera and voice stop.
4. Grant/deny microphone permission. Test Arabic and English dictation, test voice playback, missing installed voice, volume zero/nonzero, slower/faster speech, and stop during a streamed response.
5. Test actual browser speech/camera on the published web preview; browser/device availability and AI-provider CORS support vary.

## Limits
Android native compilation and physical-device verification remain uncompleted. The previous APK attempt was blocked resolving Gradle's Kotlin DSL plugin. Screen OCR/visual AI and automatic screen actions are not implemented. Camera is serial still-frame analysis, not a realtime video session.
