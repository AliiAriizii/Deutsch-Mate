# Development environment

What is installed on this machine, and the two traps that cost real time.

## Toolchain

| Piece | Version | Location |
|---|---|---|
| Flutter | 3.47.0 stable | `C:\Users\Banaizade\flutter` |
| Dart | 3.13.0 | bundled with Flutter |
| Android SDK | platform 36, build-tools 36.0.0, platform-tools 37.0.1, NDK 28.2.13676358 | `%LOCALAPPDATA%\Android\Sdk` |
| JDK | Temurin 17.0.16 | `C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot` |
| MongoDB | 8.0.8, Windows service `MongoDB`, auto-start, no auth | `127.0.0.1:27017` |
| Python | 3.13.3 | backend venv at `backend/.venv` |

Persisted user environment: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, and PATH
entries for `flutter\bin`, `platform-tools`, `cmdline-tools\latest\bin`.

Flutter targets Android with `compileSdk 36`, `minSdk 24`, `targetSdk 36`,
`ndkVersion 28.2.13676358` — read from
`flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`, not
guessed.

## Trap 1 — cmdline-tools 23 breaks gradle and the licence check

`cmdline-tools;latest` currently resolves to **rev 23**, which replaced
`sdkmanager` with a thin wrapper around the new `android` CLI. The wrapper:

- **mis-parses classic package coordinates.** `sdkmanager "ndk;28.2.13676358"`
  becomes `Package ndk not found. Package 28.2.13676358 not found.`, then the
  process dies with `0xC0000791` / exit `-1073740791`
  (`STATUS_STACK_BUFFER_OVERRUN`).
- **dropped `--licenses` entirely** (`Warning: The --licenses option is no
  longer needed`), so `flutter doctor --android-licenses` can never satisfy
  Flutter's validator and the doctor reports
  `Android license status unknown` forever.

Both AGP and Flutter hardcode `<sdk>/cmdline-tools/latest/bin/sdkmanager`, so
this is not avoidable by calling something else.

**What this repo's machine does instead:** rev **22** — the last release with a
real `sdkmanager`, and new enough to read SDK XML v4 — sits at
`cmdline-tools/latest`, and the new CLI is parked at
`cmdline-tools/android-cli/bin/android.exe`.

If you ever run `sdkmanager --update` or let Android Studio update the SDK
tools, rev 23 comes back and Android builds break again with the NDK error
above. Re-apply the same swap.

The new CLI's package naming, for reference, is `dir/name` rather than
`dir;name`: `android sdk install platforms/android-36`.

## Trap 2 — Windows Developer Mode, and what it actually blocks

`flutter pub get` ends with:

```
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

Windows only allows non-elevated symlink creation in Developer Mode, and
Flutter symlinks plugins into the *desktop* platform directories
(`windows/flutter/ephemeral/.plugin_symlinks`, same for linux/macos).

**Scope, measured rather than assumed:** this blocks only the Windows and Linux
desktop targets. Android and web are unaffected — `pub get` still writes
`.flutter-plugins-dependencies` with the correct Android plugin set
(`flutter_tts`, `shared_preferences_android`), and `flutter build apk`,
`flutter analyze`, and `flutter test` all run. The one consequence for this
project is that the desktop entries in `.flutter-plugins-dependencies` go stale
(they still list `path_provider_*`, which was dropped) until the symlink step
can complete.

Needs one elevated command — it writes to HKLM:

```powershell
# In an *Administrator* PowerShell:
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
  -Name AllowDevelopmentWithoutDevLicense -Value 1 -PropertyType DWord -Force
```

Or click through: `start ms-settings:developers` → Developer Mode → On.

## Remaining doctor findings

- **Visual Studio** is missing the "Desktop development with C++" workload.
  Only affects the *Windows desktop* target; Android and web do not need it.
- **`C:\platform-tools`** held a second `adb.exe` and was removed from the user
  PATH (files left on disk) — Flutter refuses to pick between two adb copies.

## Commands

```bash
# Flutter
flutter analyze
flutter test
flutter build apk --debug
flutter run -d chrome            # web works without Developer Mode

# Backend
cd backend
.venv/Scripts/python.exe -m pytest
.venv/Scripts/python.exe -m uvicorn app.main:app --reload --port 8000
```
