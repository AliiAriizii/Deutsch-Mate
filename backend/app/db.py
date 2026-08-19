"""Mongo connection and Beanie (ODM) initialisation."""

from __future__ import annotations

import logging

from beanie import init_beanie
from pymongo import AsyncMongoClient

from .config import settings

log = logging.getLogger(__name__)

_client: AsyncMongoClient | None = None


def document_models() -> list[type]:
    """Every Beanie document, imported lazily.

    Keeps ``app.db`` importable from scripts without pulling the whole model
    graph at module load time.
    """
    from .models.content import ContentPackage
    from .models.progress import ExerciseAttempt, LektionProgress, UserStats
    from .models.session import RefreshSession
    from .models.token import OneTimeToken
    from .models.user import User

    return [
        User,
        RefreshSession,
        OneTimeToken,
        LektionProgress,
        ExerciseAttempt,
        UserStats,
        ContentPackage,
    ]


async def connect(*, db_name: str | None = None) -> AsyncMongoClient:
    """Open the client and register every Beanie document."""
    global _client
    _client = AsyncMongoClient(settings.mongodb_url, tz_aware=True)
    name = db_name or settings.mongodb_db
    await init_beanie(database=_client[name], document_models=document_models())
    log.info("mongo connected: db=%s", name)
    return _client


async def disconnect() -> None:
    global _client
    if _client is not None:
        await _client.close()
        _client = None
        log.info("mongo disconnected")


def client() -> AsyncMongoClient:
    if _client is None:
        raise RuntimeError("Mongo client is not connected; call connect() first.")
    return _client
