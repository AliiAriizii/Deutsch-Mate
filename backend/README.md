# DeutschMate API

Local backend for the DeutschMate Flutter app. FastAPI + Beanie (ODM) on MongoDB.

Covers the three things the app cannot do client-side: real authentication with
email verification and password reset, account-linked progress that survives a
reinstall, and versioned lesson content that can be updated without an
app-store release.

## Stack

| Piece | Choice | Why |
|---|---|---|
| Framework | FastAPI 0.141 | Typed request/response, OpenAPI for free, async all the way down |
| ODM | Beanie 2.2 | Pydantic documents over PyMongo async - the closest thing MongoDB has to an ORM, and the same Pydantic models validate the HTTP layer |
| Driver | PyMongo 4.17 (async) | Beanie 2.x uses it directly; Motor is deprecated |
| Passwords | argon2-cffi | Memory-hard, no bcrypt 72-byte truncation, per-hash parameter upgrade |
| Access tokens | PyJWT, HS256, 30 min | Stateless, short-lived |
| Refresh tokens | Opaque random, SHA-256 at rest, rotating, 60 days | A database dump yields no usable token; reuse of a rotated token revokes the whole family |
| Tests | pytest + pytest-asyncio + httpx ASGI | Runs against real mongod in a throwaway DB |

## Requirements

- Python 3.13 (developed on 3.13.3)
- A running `mongod` on `mongodb://127.0.0.1:27017`

## Setup

```bash
cd backend
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt   # Windows
# .venv/bin/python -m pip install -r requirements-dev.txt          # macOS/Linux

cp .env.example .env
# then set a real secret:
#   python -c "import secrets; print(secrets.token_urlsafe(64))"
```

## Run

```bash
.venv/Scripts/python.exe -m uvicorn app.main:app --reload --port 8000
```

- Docs: <http://127.0.0.1:8000/docs>
- Health (pings Mongo, not just the process): <http://127.0.0.1:8000/api/v1/health>

## Test

```bash
.venv/Scripts/python.exe -m pytest
```

Tests use the `deutschmate_test` database and drop it before every test, so dev
data is never touched.

## Endpoints

All under `/api/v1`.

### auth

| Method | Path | Notes |
|---|---|---|
| GET | `/auth/password-policy` | The client renders the rules **before** the user types, from the same source the server enforces |
| POST | `/auth/signup` | Returns `tokens: null` while verification is pending - no half-authenticated state to persist |
| POST · GET | `/auth/verify-email` | POST for the app, GET for the emailed link. Single use |
| POST | `/auth/resend-verification` | Always reports success (no account enumeration) |
| POST | `/auth/signin` | Locks the account for 15 min after 10 failures |
| POST | `/auth/refresh` | Rotating. Call on cold start before the first frame |
| POST | `/auth/logout` | One session, or `all_devices: true` |
| POST | `/auth/forgot-password` | 6-digit code, always reports success |
| POST | `/auth/reset-password` | Code is salted with the user id, so it cannot be redeemed against another account. Revokes every session |
| POST | `/auth/change-password` | Requires the current password. Revokes every session |
| GET | `/auth/me` | |
| POST | `/auth/onboarding` | Target level, daily goal, interface language. Seeds `placement_level` |
| DELETE | `/auth/me` | Hard delete + cascade. Requires password re-auth and explicit `confirm` |

### progress

| Method | Path | Notes |
|---|---|---|
| GET | `/progress` | Everything for the signed-in account |
| POST | `/progress/sync` | Merges an offline batch, returns authoritative state |
| GET | `/progress/due-reviews` | Leitner items whose interval has elapsed |

### content

| Method | Path | Notes |
|---|---|---|
| GET | `/content/manifest` | Unauthenticated - the app needs content before sign-in |
| GET | `/content/levels/{level_id}` | Optional `?version=` pin |
| POST | `/content/packages` | Publish/upsert. Needs `X-Admin-Key` when `ADMIN_API_KEY` is set |

## Design notes

**Errors are typed, never raw.** Every failure returns

```json
{ "error": { "code": "AUTH_EMAIL_NOT_VERIFIED", "message": "...", "details": {} } }
```

The client maps `code` to a localised string; `message` is a dev fallback only.
Validation errors arrive as `details.fields = { "field": "message" }` so the app
can bind each message to the right input without parsing pydantic `loc` arrays.
The full list lives in `app/errors.py::ErrorCode`.

**No account enumeration.** Unknown email and wrong password return the same
`AUTH_INVALID_CREDENTIALS`. `resend-verification` and `forgot-password` always
report success.

**Sync cannot roll progress back.** Monotonic fields take the max of both sides
and status only moves forward, so a stale device replaying an old batch is a
no-op. Attempts carry a `client_attempt_id` and are deduplicated on it, so a
retried sync after a flaky connection never double-counts.

**Content updates without a release.** The app ships every level bundled for a
cold offline start, then compares `/content/manifest` on launch and pulls only
the levels whose `version` changed, verifying `checksum` (SHA-256 over canonical
JSON) after download.

**Mail.** `MAIL_BACKEND=console` prints the message, verification link included,
to stdout - the dev default, so the flow is fully exercisable with no SMTP
account. `MAIL_BACKEND=smtp` sends for real and raises on failure; it never
pretends to have sent.

## Layout

```
app/
  config.py     settings (pydantic-settings)
  errors.py     ErrorCode enum + typed exceptions + handlers
  security.py   argon2, password policy, JWT, opaque tokens
  db.py         Mongo client + Beanie init
  deps.py       bearer auth dependencies
  mail.py       console / SMTP sender
  models/       Beanie documents (users, sessions, tokens, progress, content)
  schemas/      request + response models
  routers/      auth, progress, content, health
tests/          pytest suite (41 tests)
```

## Not built yet

- **Content seeding.** No level packages are published; the schema and the
  reference Lektion are Phase 5 work.
- **Placement test.** `placement_level` is settable and seeded from onboarding,
  but there is no item bank or scoring endpoint yet.
- **Rate limiting** is per-account (failed sign-ins) only. There is no
  per-IP throttle - add one at the reverse proxy before exposing this publicly.
- **Deployment.** This is a local dev server: single process, no TLS, CORS
  restricted to localhost.
