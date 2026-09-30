# Persistent NOK Android signing

The persistent certificate SHA-256 is recorded in `android/signing-certificate.sha256`:
`6fc9cd39b995a30c9635c9783ca1c800c6e7c659c87cf2e303cd551a69abe78f`.

The private PKCS12 key and password are kept separately in a private recovery archive owned by the user. They must never be committed to this public repository, uploaded as workflow artifacts, or printed in logs. The key alias is `nok-release`; the key and store passwords are equal.

## GitHub Actions setup

An owner must add these two repository Actions secrets:

- `NOK_KEYSTORE_BASE64`: the single-line base64 encoding of `nok-release.p12`.
- `NOK_KEYSTORE_PASSWORD`: the password from the private recovery archive.

The workflow validates both secrets together and verifies the certificate against the public fingerprint before building. It removes the restored key afterward. Both repository secrets were configured through GitHub's settings UI on 2026-09-30 with the owner's explicit authorization. The next workflow run will validate the retained certificate and build using persistent signing. Builds made before this setup were intermediate previews that required local signing; do not confuse those artifacts with persistently signed builds.

## Signing a downloaded build

Use Android SDK Build Tools 36.0.0 and Java 17 or newer:

```sh
python scripts/sign_apk.py INPUT.apk OUTPUT.apk /private/nok-release.p12 /private/password.txt /sdk/build-tools/36.0.0/lib/apksigner.jar /sdk/build-tools/36.0.0/zipalign
```

This aligns the APK for 16 KB pages, signs it, verifies its signature and alignment, and checks its certificate before replacing the output. It never overwrites the input or prints the password. Reuse this same key for future updates, and increment `pubspec.yaml`'s build number.

The 0.1.0 and 0.1.1 previews used different temporary runner keys. The new key cannot update those installations in place. Preserve important chats before any uninstall. This does not indicate tested installation on a physical device.
