# Deploying the backend

Short answer: **Vercel can host it, but it is the wrong shape for this
backend, and you will pay for that in complexity rather than money.** The
monorepo layout is the easy part. Read the trade-off before committing.

---

## Why Vercel fights this app

Vercel Python is **serverless functions**: each request may land on a cold
process, and nothing survives between invocations. Four consequences here:

1. **`init_beanie` runs in a lifespan handler.** Vercel's Python adapter does
   not reliably run ASGI lifespan events, so the app can start with no document
   models registered and every route 500s. This has to move to a lazy,
   idempotent init on first use.
2. **MongoDB connections do not pool across invocations.** Each cold start opens
   a new connection. A busy serverless app will exhaust an Atlas free tier's
   connection limit (500 on M0) far sooner than you would expect. The fix is a
   module-level cached client plus `maxPoolSize=1`.
3. **Your local `mongod` is unreachable** from Vercel. You need **MongoDB
   Atlas** (or another hosted Mongo) regardless of which host you pick.
4. **Cold starts.** `cryptography` + `pymongo` + `fastapi` is a chunky bundle;
   expect a slow first request after idle. For a sign-in endpoint that is felt
   directly.

None of this is fatal. It is just work that buys you nothing, because this
backend is a long-lived stateful service, not an edge function.

## What I would actually use

| Host | Fit | Notes |
|---|---|---|
| **Railway** | best | Real long-running process. `uvicorn` as-is, no code changes. Managed Mongo add-on or Atlas. ~$5/mo |
| **Render** | best | Same shape, free tier that sleeps on idle (fine for testing) |
| **Fly.io** | good | Closest to a real VM, more control, more setup |
| **Vercel** | workable | Only worth it if the rest of your stack already lives there |

On Railway or Render the deployment is: point it at the repo, set the root
directory to `backend`, set the start command, add the environment variables.
The code below is needed **only for Vercel**.

---

## If you do want Vercel

### 1. The monorepo is not a problem

Vercel takes a **Root Directory** setting. Point the project at `backend/` and
it ignores the `frontend/` Flutter app entirely.

Project settings → General → Root Directory → `backend`.

### 2. Add the function entrypoint

Vercel looks for `api/index.py` and serves the ASGI app it finds there.

```python
# backend/api/index.py
from app.main import app  # noqa: F401  - Vercel serves this ASGI callable
```

### 3. `vercel.json`

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "rewrites": [{ "source": "/(.*)", "destination": "/api/index" }]
}
```

Every path routes to the one function; FastAPI does its own routing inside.

### 4. Make Mongo init lazy

This is the change that matters. Today `app/main.py` connects in a lifespan
handler. Under Vercel it must connect on first use and cache the client at
module scope, so warm invocations reuse it:

```python
_ready = False

async def ensure_db() -> None:
    global _ready
    if _ready:
        return
    await connect()          # init_beanie, cached AsyncMongoClient
    _ready = True
```

…called from a dependency on every router, or from middleware. Also set
`maxPoolSize=1` on the client, since each instance serves one request at a
time and a large pool per instance multiplies connections for nothing.

### 5. Environment variables

Set in Vercel project settings, not in a file:

```
MONGODB_URL=mongodb+srv://...@cluster.mongodb.net/?retryWrites=true&w=majority
MONGODB_DB=deutschmate
JWT_SECRET=<a fresh 64-byte secret, not the local one>
APP_ENV=prod
GOOGLE_CLIENT_IDS=<web>,<android-debug>,<android-upload>
PUBLIC_BASE_URL=https://<your-project>.vercel.app
MAIL_BACKEND=smtp
SMTP_HOST=...
ADMIN_API_KEY=<required in prod, or content publishing is refused>
```

Two that will bite:

- **`MAIL_BACKEND=console` prints verification links to the log.** In
  production that means nobody can verify an email, and the links sit in your
  server logs. Set up real SMTP before anyone signs up.
- `APP_ENV=prod` makes the app **refuse to start** with the placeholder
  `JWT_SECRET`. That guard is deliberate.

### 6. Atlas network access

Vercel functions have no fixed egress IPs on the Hobby plan, so Atlas must
allow `0.0.0.0/0` and you are relying entirely on credentials. That is another
reason a fixed-IP host is a better fit. Use a strong database password and a
user scoped to the one database.

### 7. Point the app at it

```bash
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=https://<project>.vercel.app
```

Once it is HTTPS you can also drop the debug cleartext exception, which only
exists for the local server.

---

## Before any of this is public

Currently missing and worth fixing first:

- **No per-IP rate limiting.** Sign-in is limited per account only, so the
  endpoints are open to distributed brute force and to signup spam. Add limits
  at the edge or in middleware.
- **CORS is localhost-only**, which is correct for a mobile client, but wrong
  the moment a web build talks to it.
- **No database backups.** Atlas free tier has none. Progress "surviving a
  reinstall" is only true if the database survives too.
- **The MCP Vercel integration in this session is unauthenticated**, so I
  cannot create or inspect the project for you — that part is yours in the
  dashboard or via `vercel login` in a terminal.
