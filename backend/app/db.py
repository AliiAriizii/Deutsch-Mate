"""Mongo connection and Beanie (ODM) initialisation."""

from __future__ import annotations

import asyncio
import logging

from beanie import init_beanie
from pymongo import AsyncMongoClient

from .config import settings

log = logging.getLogger(__name__)

_client: AsyncMongoClient | None = None
_ready = False
# AsyncMongoClient and asyncio.Lock both bind to the event loop they are first
# used on, so the loop they belong to is part of the cached state.
_loop: asyncio.AbstractEventLoop | None = None
_init_lock: asyncio.Lock | None = None


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
    """Open the client and register every Beanie document.

    Always builds a fresh client, so tests can point at another database.
    Request paths should call :func:`ensure_db` instead.
    """
    global _client, _ready, _loop
    _client = AsyncMongoClient(
        settings.mongodb_url,
        tz_aware=True,
        maxPoolSize=settings.mongo_max_pool_size,
    )
    name = db_name or settings.mongodb_db
    await init_beanie(database=_client[name], document_models=document_models())
    _loop = asyncio.get_running_loop()
    _ready = True
    log.info("mongo connected: db=%s pool=%d", name, settings.mongo_max_pool_size)
    return _client


async def ensure_db() -> None:
    """Connect once per event loop, on first use.

    A long-lived server connects in the lifespan handler and this is a no-op.
    Serverless hosts do not reliably run ASGI lifespan events, so without this
    the first request would find no document models registered.

    Keyed on the running loop, not just a flag: a host that runs a fresh loop
    per invocation would otherwise reuse a client bound to a dead one, which
    raises rather than reconnecting. The lock keeps concurrent requests on a
    cold instance from each opening their own client.
    """
    global _ready, _init_lock

    running = asyncio.get_running_loop()
    if _ready and _loop is running:
        return

    if _init_lock is None or _loop is not running:
        _init_lock = asyncio.Lock()
        _ready = False

    async with _init_lock:
        if _ready and _loop is running:
            return
        await connect()


async def disconnect() -> None:
    global _client, _ready, _loop
    client_, loop_ = _client, _loop
    _client = None
    _loop = None
    _ready = False

    if client_ is None:
        return
    if loop_ is not None and loop_ is not asyncio.get_running_loop():
        # Bound to a loop that has moved on; closing it from here would raise.
        log.info("mongo client dropped (belongs to another event loop)")
        return
    await client_.close()
    log.info("mongo disconnected")


def client() -> AsyncMongoClient:
    if _client is None:
        raise RuntimeError("Mongo client is not connected; call connect() first.")
    return _client
