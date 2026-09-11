"""The serverless cold start.

Vercel does not reliably run ASGI lifespan events, so nothing calls
``connect()`` before the first request arrives. These tests drive the app the
way a cold function instance does: build it, send a request, expect it to have
connected itself.
"""

from __future__ import annotations

import asyncio

import pytest
from httpx import ASGITransport, AsyncClient

from app import db as db_module
from app.config import Settings
from app.db import disconnect
from app.main import create_app

API = "/api/v1"


@pytest.mark.asyncio
async def test_first_request_connects_without_a_lifespan() -> None:
    await disconnect()
    assert db_module._ready is False, "precondition: nothing is connected"

    # ASGITransport does not run lifespan, which is the whole point here.
    async with AsyncClient(
        transport=ASGITransport(app=create_app()), base_url="http://vercel"
    ) as client:
        resp = await client.get(f"{API}/health")

    assert resp.status_code == 200
    assert resp.json()["ok"] is True
    assert db_module._ready is True


@pytest.mark.asyncio
async def test_concurrent_cold_requests_connect_once(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Ten requests hitting a cold instance must open one client between them.

    Counted, not assumed: every extra client here is another connection held
    against the Atlas per-cluster cap.
    """
    await disconnect()

    real_connect = db_module.connect
    calls = 0

    async def counting_connect(**kwargs):
        nonlocal calls
        calls += 1
        # A real connect is slow enough to overlap; make that certain.
        await asyncio.sleep(0)
        return await real_connect(**kwargs)

    monkeypatch.setattr(db_module, "connect", counting_connect)

    async with AsyncClient(
        transport=ASGITransport(app=create_app()), base_url="http://vercel"
    ) as client:
        results = await asyncio.gather(
            *(client.get(f"{API}/health") for _ in range(10))
        )

    assert {r.status_code for r in results} == {200}
    assert all(r.json()["ok"] for r in results)
    assert calls == 1, f"connected {calls} times, expected once"


def test_the_pool_shrinks_on_vercel() -> None:
    """A large pool per instance multiplies connections against the Atlas cap.

    Not 1: Fluid Compute puts several concurrent requests on one instance, and
    a pool of one would serialise them.
    """
    assert Settings(vercel="1").is_serverless is True
    assert Settings(vercel="1").mongo_max_pool_size == 5

    assert Settings(vercel="").is_serverless is False
    assert Settings(vercel="").mongo_max_pool_size == 100
