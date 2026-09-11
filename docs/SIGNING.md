# Android signing

## What exists

| | |
|---|---|
| Keystore | `C:\Users\Banaizade\keystores\deutschmate-upload.p12` — **outside the repo** |
| Format | PKCS12 (the industry standard; `keytool` warns that JKS is proprietary) |
| Key | RSA 4096, `SHA384withRSA`, alias `upload` |
| Validity | 30 years, to 2056-08-12 (Play requires validity past 2033) |
| Password | in `android/key.properties`, which is gitignored |
| Gradle wiring | `android/app/build.gradle.kts` reads `key.properties`; falls back to debug signing when absent |

`android/key.properties` is ignored by both `android/.gitignore` (Flutter's template) and the root `.gitignore`, which also blocks `*.p12`, `*.jks`, `*.keystore` as a backstop. Verified with `git check-ignore`.

## Fingerprints

These are **not secret** — they are published in every APK you ship. Register them with Google.

**Upload key** (release builds):
```
SHA-1:   B7:9C:27:03:34:A8:1F:2F:E1:48:0B:38:FF:31:0F:22:C7:84:4A:19
SHA-256: FE:52:77:64:D0:FB:38:02:41:4D:74:19:3D:90:68:A3:55:5F:3E:38:63:2C:2F:48:61:05:71:3D:C5:FA:02:95
```

**Debug key** (`~/.android/debug.keystore`, password `android`, shared by every Flutter debug build on this machine):
```
SHA-1:   D8:BA:A7:B0:98:33:CA:CC:95:E5:BE:13:A6:BE:07:13:16:EE:69:59
SHA-256: 91:FD:DB:91:48:00:91:9A:B1:56:98:94:AC:31:C5:DF:4E:71:F6:A9:0F:71:F1:BF:AC:27:84:A2:2B:33:2A:A0
```

Regenerate at any time:
```bash
keytool -list -v -keystore <path> -alias <alias>
```

## The three-fingerprint trap

Google Sign-In on Android matches the certificate that signed the *installed* APK. With **Play App Signing** (default for new apps) Google re-signs your upload with a different key, so the certificate on a user's device is **not** your upload key.

You therefore need **three** SHA-1 values registered on the Android OAuth client:

1. **Debug** — so sign-in works while developing.
2. **Upload** — so it works for an APK you sideload or distribute directly.
3. **Play app signing** — copied from *Play Console → Test and release → Setup → App signing*, available only after the first upload.

Miss #3 and you get the classic "works in debug, works on my sideloaded build, fails for everyone who installs from Play". It is the single most common failure in this feature.

## Back this up now

The keystore exists in exactly one place on one disk. Copy it somewhere durable — password manager attachment, encrypted archive, or an offline drive — together with its password.

Losing it is **recoverable but annoying**: because it is an upload key under Play App Signing, you can request an upload-key reset from Google and keep the app listing. Losing an *app signing* key with Play App Signing disabled is unrecoverable — you would have to publish a new listing and lose every existing install and review. Do not disable Play App Signing.

## Rotate the password if you want to

The password was generated locally and written only to `key.properties` — but it did pass through the session that created it. If that bothers you:

```bash
keytool -storepasswd -keystore C:/Users/Banaizade/keystores/deutschmate-upload.p12
keytool -keypasswd  -keystore C:/Users/Banaizade/keystores/deutschmate-upload.p12 -alias upload
```

Then update `storePassword` and `keyPassword` in `android/key.properties`. Fingerprints do **not** change — the key material is untouched, so nothing needs re-registering with Google.

## Building

```bash
flutter build apk --release        # signed with the upload key
flutter build appbundle --release  # what Play actually wants
```

Verify which certificate an artifact carries:
```bash
# apksigner ships with build-tools
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

Release builds also run R8 with `isMinifyEnabled` and `isShrinkResources`, so `android/app/proguard-rules.pro` keeps the Flutter engine and `flutter_tts` reflective entry points. If a release build crashes where debug does not, that file is the first suspect.
