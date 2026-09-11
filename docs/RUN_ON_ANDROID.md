# Running on Android

Android is the only place Google sign-in actually works. Web cannot do it
(`google_sign_in_web` reports `supportsAuthenticate() == false` — Google's web
SDK requires its own rendered button), and Windows has no implementation at all.

Two routes. The phone needs no downloads.

---

## Route A — a physical phone (fastest, and the most realistic test)

### 1. Put the phone in developer mode

Settings → About phone → tap **Build number** seven times → back → Developer
options → **USB debugging** on. Connect by USB and accept the RSA fingerprint
prompt on the phone.

Confirm the PC sees it:

```bash
cd frontend
flutter devices
```

### 2. Bind the backend to the network, not just loopback

This is the step that silently breaks everything. `--host 127.0.0.1` is only
reachable from the PC itself; the phone gets a connection refused that looks
exactly like a broken app.

```bash
cd backend
.venv/Scripts/python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Let the phone through Windows Firewall

Also silent: Windows blocks inbound 8000 by default. In an **Administrator**
PowerShell, once:

```powershell
New-NetFirewallRule -DisplayName "DeutschMate dev API" -Direction Inbound `
  -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
```

`-Profile Private` keeps it to networks you have marked private — do not open it
on a public network.

### 4. Run, pointing the app at your PC

The app defaults to `10.0.2.2`, which is emulator-only. A phone needs your
actual LAN address:

```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://192.168.15.218:8000
```

That IP is this machine's Wi-Fi address as of writing — re-check with
`ipconfig` if the network changes. Phone and PC must be on the same Wi-Fi, and
the network must not be a guest network with client isolation.

### 5. Sanity check from the phone

Open `http://192.168.15.218:8000/api/v1/health` in the phone's browser. Expect
`{"ok": true, ...}`. If that fails, the app will fail too, and the cause is
step 2 or 3 — not the app.

---

## Route B — an emulator

Nothing is installed yet: no `emulator` package, no system image, no AVD.
Roughly 2 GB to download and ~8 GB on disk once running.

```bash
SDK="$LOCALAPPDATA/Android/Sdk"
"$SDK/cmdline-tools/latest/bin/sdkmanager" \
  "emulator" \
  "system-images;android-36;google_apis;x86_64"

"$SDK/cmdline-tools/latest/bin/avdmanager" create avd \
  -n deutschmate -k "system-images;android-36;google_apis;x86_64" -d pixel_7

"$SDK/emulator/emulator" -avd deutschmate
```

Then plain `flutter run` — the app's Android default of `10.0.2.2:8000` already
points at the host's loopback as seen from inside the emulator, so the backend
can stay on `127.0.0.1` and no firewall rule is needed.

**The image must be `google_apis`.** A plain AOSP image has no Play Services,
and Google sign-in fails on it in a way that looks like a configuration bug.
`google_apis_playstore` also works.

Requires hardware acceleration — Windows Hypervisor Platform (or Hyper-V)
enabled in Windows Features. Without it the emulator either refuses to start or
runs unusably slowly.

---

## Why sign-in should work on Android

Already in place:

- The **debug** OAuth client is registered against the debug keystore's SHA-1
  (`D8:BA:A7:...:69:59`), and a debug build is signed with that key. See
  [SIGNING.md](SIGNING.md).
- `serverClientId` is the web client id, which is what makes Google mint an ID
  token rather than only an access token.
- The backend accepts all three client ids as `aud`.
- `frontend/android/app/src/debug/` permits cleartext HTTP to loopback addresses, so a
  debug build can talk to a local server. The release manifest does not.

## When it fails, in order of likelihood

| Symptom | Cause |
|---|---|
| `GOOGLE_MISCONFIGURED` / code 10 | SHA-1 mismatch. A debug build needs the *debug* SHA-1 registered; an installed release build needs the upload **and** Play app-signing ones |
| `GOOGLE_NO_ID_TOKEN` | `serverClientId` missing or wrong — Google returned an access token only |
| `AUTH_TOKEN_INVALID` from our server | The token's `aud` is not in `GOOGLE_CLIENT_IDS` in `backend/.env` |
| "cannot reach the server" | Backend on `127.0.0.1` instead of `0.0.0.0`, or the firewall rule is missing (phone only) |
| Sign-in dialog never appears | Emulator image without Play Services |
