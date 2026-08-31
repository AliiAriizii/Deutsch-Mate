# Google Sign-In setup

The server side is built and tested. What remains needs your Google account in
a browser — there is **no public API for creating OAuth 2.0 client IDs**, and
`gcloud` does not cover it, so this part cannot be automated.

Values below are already filled in for this project. Copy them as written.

---

## 1. Google Cloud project

<https://console.cloud.google.com>

1. Create a project — suggested name `DeutschMate`.
2. **APIs & Services → OAuth consent screen**
   - User type: **External**
   - App name: `DeutschMate`
   - Support email: yours
   - Scopes: `openid`, `email`, `profile` — nothing more. Anything beyond these
     triggers Google's verification review, which you do not want to sit through
     for a sign-in button.
   - Publishing status: **Testing** is fine while developing; add your own
     account under *Test users*. Move to *In production* before public release
     (no review needed while the scopes stay basic).

## 2. Android OAuth client

**Credentials → Create credentials → OAuth client ID → Android**

| Field | Value |
|---|---|
| Package name | `com.deutschmate.app` |
| SHA-1 (debug) | `D8:BA:A7:B0:98:33:CA:CC:95:E5:BE:13:A6:BE:07:13:16:EE:69:59` |

Then create a **second** Android client with the upload key's SHA-1 — one client
holds one fingerprint:

| Field | Value |
|---|---|
| Package name | `com.deutschmate.app` |
| SHA-1 (upload) | `B7:9C:27:03:34:A8:1F:2F:E1:48:0B:38:FF:31:0F:22:C7:84:4A:19` |

And a **third**, later: after your first Play upload, copy the SHA-1 from
*Play Console → Test and release → Setup → App signing*. Google re-signs your
bundle, so the certificate on a user's device is neither of the two above. Skip
this and sign-in works for you and fails for everyone who installs from Play.
This is the single most common failure in this feature — see
[SIGNING.md](SIGNING.md).

## 3. Web OAuth client — required even with no website

**Credentials → Create credentials → OAuth client ID → Web application**

Name it `DeutschMate backend`. No redirect URI is needed for the Android flow.

This client id does two jobs:

- it is `serverClientId` in the Flutter app, which is what makes Google mint an
  **ID token** rather than only an access token;
- it is the `aud` the backend expects when verifying that token.

Without it there is nothing for the server to verify against.

## 4. Backend configuration

Put every client id in `backend/.env`, comma separated — Android, web, and
later iOS are all legitimately this app:

```ini
GOOGLE_CLIENT_IDS=<web-client-id>,<android-debug-client-id>,<android-upload-client-id>
```

Leaving it empty disables Google sign-in and the endpoint answers
`AUTH_PROVIDER_NOT_CONFIGURED` — verified by test.

Restart the server. No code changes.

---

## What the server already does

`POST /api/v1/auth/oauth/google` — sign in or sign up
`POST /api/v1/auth/oauth/google/link` — connect Google to an existing password account

Verification on every call: RS256 signature against Google's live JWKS
(`https://www.googleapis.com/oauth2/v3/certs`, keys cached 12h, unknown `kid`
triggers a refetch so a key rotation is not an outage), `aud` in the configured
set, `iss` in `{accounts.google.com, https://accounts.google.com}`, `exp`/`iat`
with 30s leeway, `email_verified`, and the nonce.

The client sends **no identity of its own** — no email, no user id. Everything
acted on is read out of the verified token. A request body of
`{"email": "victim@example.com"}` is rejected as malformed.

### Account linking

One account per verified email address, however you got in:

| Situation | Behaviour |
|---|---|
| Google identity already linked | sign in |
| No account for the address | create, pre-verified (Google asserted it) |
| Account exists, provider-only | link, sign in |
| Account exists **with a password** | **409 `AUTH_LINK_REQUIRES_PASSWORD`** — the client prompts for the password once and calls `/link` |

That last row is the case that matters. Linking automatically would let anyone
who can obtain a Google account for that address take over an existing account.

Identity is keyed on Google's `sub`, never the email address — so a Workspace
rename does not orphan the account, and Apple's "Hide My Email" relay addresses
will not confuse the same code path later.

### Other behaviours worth knowing

- A Google-only account has `password_hash = None`, not an empty string. Every
  password path guards on it, so there is no silent comparison against `None`.
- Password sign-in on a Google-only account answers
  `AUTH_USE_PROVIDER_SIGNIN` with the provider list, instead of a password that
  is permanently "wrong". This does reveal the address is registered — but
  signup's `AUTH_EMAIL_TAKEN` already reveals exactly that, so it discloses
  nothing new.
- Deleting a Google-only account requires a **fresh Google token**, since there
  is no password to re-authenticate with. A stolen access token alone cannot
  destroy an account, and a token belonging to a *different* Google user is
  rejected.
- A race between two simultaneous first-time sign-ins for the same address
  resolves to one account rather than an error.

### Test coverage

22 tests in `backend/tests/test_oauth.py`, which mint their own RSA key so the
real verification path runs without touching Google. The forgery cases:

- token signed by a different key → rejected
- `alg=none` unsigned token → rejected
- genuine Google token minted for **another app** → rejected
- wrong issuer, expired token, unverified email → rejected
- nonce mismatch → rejected; SHA-256-of-raw-nonce → accepted
- client posting a bare email instead of a token → 422

---

## Then the client

Not built yet, and deliberately: it cannot be verified end to end without the
real client IDs from the steps above. Once you paste them in, the client work is

1. `google_sign_in: ^7.x` — note v7 changed the API to
   `GoogleSignIn.instance` / `initialize()` / `authenticate()`; v6 tutorials
   will not compile.
2. `flutter_secure_storage` for the token pair (currently the app still uses the
   `SharedPreferences` stub that accepts any password).
3. An API client for the endpoints above, with the `error.code` → Persian
   message map.
4. The "Continue with Google" button, and the link prompt for the 409 case.
