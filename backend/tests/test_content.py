"""Content delivery: manifest, versioned download, checksum stability."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from .conftest import API

pytestmark = pytest.mark.asyncio


def _payload(version_note: str = "v1") -> dict:
    """Minimal shape of a level package - enough to exercise node counting."""
    return {
        "level_id": "A1.1",
        "note": version_note,
        "module": [
            {
                "id": "a1.1.m1",
                "lektionen": [
                    {
                        "id": "a1.1.m1.l1",
                        "sections": [
                            {"kind": "wortschatz", "exercises": [{"id": "e1"}, {"id": "e2"}]},
                            {"kind": "grammatik", "exercises": [{"id": "e3"}]},
                        ],
                    },
                    {
                        "id": "a1.1.m1.l2",
                        "sections": [{"kind": "einstieg", "exercises": [{"id": "e4"}]}],
                    },
                ],
            }
        ],
    }


async def test_manifest_is_empty_before_publishing(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/content/manifest")
    assert resp.status_code == 200
    assert resp.json()["entries"] == []


async def test_publish_then_manifest_then_download(client: AsyncClient) -> None:
    published = await client.post(
        f"{API}/content/packages",
        json={"level_id": "A1.1", "version": "1.0.0", "payload": _payload()},
    )
    assert published.status_code == 201, published.text
    entry = published.json()
    assert entry["lektion_count"] == 2
    assert entry["exercise_count"] == 4
    assert len(entry["checksum"]) == 64

    manifest = await client.get(f"{API}/content/manifest")
    entries = manifest.json()["entries"]
    assert [e["level_id"] for e in entries] == ["A1.1"]
    assert entries[0]["version"] == "1.0.0"

    pkg = await client.get(f"{API}/content/levels/A1.1")
    assert pkg.status_code == 200
    assert pkg.json()["payload"]["module"][0]["id"] == "a1.1.m1"
    assert pkg.json()["checksum"] == entry["checksum"]


async def test_checksum_changes_only_when_content_changes(
    client: AsyncClient,
) -> None:
    same_a = await client.post(
        f"{API}/content/packages",
        json={"level_id": "A1.2", "version": "1.0.0", "payload": _payload("stable")},
    )
    same_b = await client.post(
        f"{API}/content/packages",
        json={"level_id": "A1.2", "version": "1.0.1", "payload": _payload("stable")},
    )
    different = await client.post(
        f"{API}/content/packages",
        json={"level_id": "A1.2", "version": "1.0.2", "payload": _payload("edited")},
    )
    assert same_a.json()["checksum"] == same_b.json()["checksum"]
    assert different.json()["checksum"] != same_a.json()["checksum"]


async def test_newest_published_version_wins_in_the_manifest(
    client: AsyncClient,
) -> None:
    await client.post(
        f"{API}/content/packages",
        json={"level_id": "A2.1", "version": "1.0.0", "payload": _payload("old")},
    )
    await client.post(
        f"{API}/content/packages",
        json={"level_id": "A2.1", "version": "1.1.0", "payload": _payload("new")},
    )
    manifest = await client.get(f"{API}/content/manifest")
    a21 = [e for e in manifest.json()["entries"] if e["level_id"] == "A2.1"]
    assert len(a21) == 1
    assert a21[0]["version"] == "1.1.0"

    # An older version stays fetchable by explicit pin.
    pinned = await client.get(f"{API}/content/levels/A2.1", params={"version": "1.0.0"})
    assert pinned.status_code == 200
    assert pinned.json()["payload"]["note"] == "old"


async def test_unknown_version_is_typed(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/content/levels/A1.1", params={"version": "9.9.9"})
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "CONTENT_VERSION_UNKNOWN"


async def test_unpublished_draft_is_not_served(client: AsyncClient) -> None:
    await client.post(
        f"{API}/content/packages",
        json={
            "level_id": "B1.2",
            "version": "0.1.0",
            "payload": _payload("draft"),
            "publish": False,
        },
    )
    manifest = await client.get(f"{API}/content/manifest")
    assert not [e for e in manifest.json()["entries"] if e["level_id"] == "B1.2"]

    latest = await client.get(f"{API}/content/levels/B1.2")
    assert latest.status_code == 404

    # Still reachable by explicit version, which is how authoring previews it.
    draft = await client.get(f"{API}/content/levels/B1.2", params={"version": "0.1.0"})
    assert draft.status_code == 200


async def test_invalid_level_id_is_rejected(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/content/levels/C2.9")
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_health_reports_mongo(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["ok"] is True
    assert body["mongo"]["reachable"] is True
    assert body["database"] == "deutschmate_test"
