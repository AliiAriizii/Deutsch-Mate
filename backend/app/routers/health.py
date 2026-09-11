"""Liveness / readiness."""

from __future__ import annotations

from fastapi import APIRouter

from ..config import settings
from ..db import client, ensure_db
from ..security import now

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, object]:
    """Readiness, not just liveness: pings Mongo so a dead DB shows up here
    instead of as a 500 on the first real request."""
    mongo_ok = True
    mongo_error: str | None = None
    try:
        await ensure_db()
        await client().admin.command("ping")
    except Exception as exc:  # surfaced, not swallowed
        mongo_ok = False
        mongo_error = type(exc).__name__

    return {
        "ok": mongo_ok,
        "env": settings.app_env,
        "database": settings.mongodb_db,
        "mongo": {"reachable": mongo_ok, "error": mongo_error},
        "server_time": now().isoformat(),
    }
