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
   models registered and every route 500s. This is now handled by a lazy,
   idempotent init on first use (`app.db.ensure_db`).
2. **MongoDB connections do not pool across invocations.** Each cold start opens
   a new connection, and every live instance holds its own pool, so a busy
   deployment can exhaust an Atlas free tier's connection limit (500 on M0)
   faster than you would expect. `settings.mongo_max_pool_size` drops the pool
   to 5 when `VERCEL` is set. Not 1: Fluid Compute serves several concurrent
   requests per instance, so a pool of one would serialise every query.
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

The code side is already done and committed. What is left is the dashboard.

### 1. The monorepo is not a problem

Vercel takes a **Root Directory** setting. Point the project at `backend/` and
it ignores the `frontend/` Flutter app entirely.

Project settings → General → Root Directory → `backend`.

### 2. What is already in the repo

| File | Purpose |
|---|---|
| `backend/api/index.py` | The function entrypoint. Vercel serves the ASGI callable it finds here |
| `backend/vercel.json` | Rewrites every path to that one function; FastAPI routes internally |
| `backend/.python-version` | Pins Python 3.13, which `requirements.txt` is resolved against |
| `backend/.vercelignore` | Keeps tests and dev requirements out of the bundle |

`app/db.py` gained `ensure_db()`: an idempotent connect-on-first-use guarded by
an `asyncio.Lock`, so concurrent requests on a cold instance open one client
between them. `app/main.py` attaches it as a dependency on the auth, progress
and content routers. Health is deliberately excluded — it has to answer even
when Mongo is unreachable, and it reports the failure in its body instead.

The lifespan handler is untouched, so a local `uvicorn` run still connects at
startup and `ensure_db()` is a no-op there.

### 3. Environment variables

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

### 4. Atlas network access

Vercel functions have no fixed egress IPs on the Hobby plan, so Atlas must
allow `0.0.0.0/0` and you are relying entirely on credentials. That is another
reason a fixed-IP host is a better fit. Use a strong database password and a
user scoped to the one database.

### 5. Point the app at it

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
