"""FastAPI application entrypoint.

Run locally:
    cd backend
    python -m uvicorn app.main:app --reload --port 8000
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .db import connect, disconnect
from .errors import register_error_handlers
from .routers import auth, content, health, progress

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
)

API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(_: FastAPI):
    await connect()
    try:
        yield
    finally:
        await disconnect()


def create_app() -> FastAPI:
    app = FastAPI(
        title="DeutschMate API",
        version="1.0.0",
        summary="Auth, progress, and versioned lesson content for the DeutschMate app.",
        lifespan=lifespan,
        docs_url="/docs",
        openapi_url="/openapi.json",
    )

    app.add_middleware(
        CORSMiddleware,
        # Flutter web dev servers bind a random port, so exact origins are not
        # knowable; regex covers localhost on any port and nothing else.
        allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_error_handlers(app)

    app.include_router(health.router, prefix=API_PREFIX)
    app.include_router(auth.router, prefix=API_PREFIX)
    app.include_router(progress.router, prefix=API_PREFIX)
    app.include_router(content.router, prefix=API_PREFIX)

    @app.get("/", include_in_schema=False)
    async def root() -> dict[str, str]:
        return {
            "service": "deutschmate-api",
            "env": settings.app_env,
            "docs": "/docs",
            "health": f"{API_PREFIX}/health",
        }

    return app


app = create_app()
