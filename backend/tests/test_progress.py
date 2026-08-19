"""Progress sync: survives reinstall, tolerates replays, never rolls back."""

from __future__ import annotations

from datetime import date

import pytest
from httpx import AsyncClient

from .conftest import API, GOOD_PASSWORD, MailSpy, auth_header, signup_and_verify

pytestmark = pytest.mark.asyncio


def _lektion(
    *,
    status: str = "in_progress",
    xp: int = 40,
    score: int = 60,
    revision: int = 1,
    seconds: int = 300,
) -> dict:
    return {
        "level_id": "A1.1",
        "lektion_id": "a1.1.m1.l1",
        "modul_id": "a1.1.m1",
        "status": status,
        "sections": [
            {"kind": "wortschatz", "completed": True, "correct_count": 8, "total_count": 10}
        ],
        "xp_earned": xp,
        "best_score_percent": score,
        "seconds_spent": seconds,
        "revision": revision,
    }


def _attempt(client_id: str, *, correct: bool = True) -> dict:
    return {
        "lektion_id": "a1.1.m1.l1",
        "section_kind": "wortschatz",
        "exercise_id": "a1.1.m1.l1.wortschatz.flash.003",
        "is_correct": correct,
        "given_answer": "die Sprache",
        "response_ms": 1400,
        "leitner_box": 2,
        "client_attempt_id": client_id,
    }


async def test_progress_requires_auth(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/progress")
    assert resp.status_code == 401


async def test_sync_creates_then_returns_authoritative_state(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="sync@example.com")
    headers = auth_header(auth)

    resp = await client.post(
        f"{API}/progress/sync",
        json={
            "lektionen": [_lektion()],
            "attempts": [_attempt("att-1")],
            "minutes_studied_delta": 12,
            "active_date": "2026-08-20",
        },
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["attempts_accepted"] == 1
    assert body["attempts_duplicate"] == 0
    assert len(body["lektionen"]) == 1
    assert body["lektionen"][0]["lektion_id"] == "a1.1.m1.l1"
    assert body["stats"]["total_xp"] == 40
    assert body["stats"]["minutes_studied"] == 12
    assert body["stats"]["current_streak"] == 1


async def test_replayed_attempt_batch_is_not_double_counted(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="replay@example.com")
    headers = auth_header(auth)
    payload = {"lektionen": [], "attempts": [_attempt("att-dup")]}

    first = await client.post(f"{API}/progress/sync", json=payload, headers=headers)
    second = await client.post(f"{API}/progress/sync", json=payload, headers=headers)

    assert first.json()["attempts_accepted"] == 1
    assert second.json()["attempts_accepted"] == 0
    assert second.json()["attempts_duplicate"] == 1


async def test_stale_device_cannot_roll_back_progress(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="stale@example.com")
    headers = auth_header(auth)

    await client.post(
        f"{API}/progress/sync",
        json={"lektionen": [_lektion(status="completed", xp=100, score=95, revision=5)]},
        headers=headers,
    )
    # An older device wakes up and pushes its stale view.
    resp = await client.post(
        f"{API}/progress/sync",
        json={"lektionen": [_lektion(status="in_progress", xp=10, score=20, revision=1)]},
        headers=headers,
    )

    lektion = resp.json()["lektionen"][0]
    assert lektion["status"] == "completed"
    assert lektion["xp_earned"] == 100
    assert lektion["best_score_percent"] == 95
    assert lektion["revision"] == 5


async def test_streak_increments_on_consecutive_days_and_resets_on_a_gap(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="streak@example.com")
    headers = auth_header(auth)

    async def push(day: date) -> dict:
        resp = await client.post(
            f"{API}/progress/sync",
            json={"lektionen": [], "attempts": [], "active_date": day.isoformat()},
            headers=headers,
        )
        return resp.json()["stats"]

    assert (await push(date(2026, 8, 18)))["current_streak"] == 1
    assert (await push(date(2026, 8, 19)))["current_streak"] == 2
    # Same day again must not inflate the streak.
    assert (await push(date(2026, 8, 19)))["current_streak"] == 2
    assert (await push(date(2026, 8, 20)))["current_streak"] == 3

    after_gap = await push(date(2026, 8, 25))
    assert after_gap["current_streak"] == 1
    assert after_gap["longest_streak"] == 3


async def test_progress_survives_a_reinstall(client: AsyncClient, mail: MailSpy) -> None:
    """The point of server-side progress: wipe the device, sign in, get it back."""
    auth = await signup_and_verify(client, mail, email="reinstall@example.com")
    await client.post(
        f"{API}/progress/sync",
        json={"lektionen": [_lektion(status="completed", xp=75)]},
        headers=auth_header(auth),
    )

    # "Reinstall": brand-new sign-in, nothing carried over locally.
    fresh = await client.post(
        f"{API}/auth/signin",
        json={"email": "reinstall@example.com", "password": GOOD_PASSWORD},
    )
    restored = await client.get(f"{API}/progress", headers=auth_header(fresh.json()))
    assert restored.status_code == 200
    body = restored.json()
    assert body["stats"]["total_xp"] == 75
    assert body["lektionen"][0]["status"] == "completed"


async def test_progress_is_scoped_to_the_owning_account(
    client: AsyncClient, mail: MailSpy
) -> None:
    mine = await signup_and_verify(client, mail, email="mine@example.com")
    theirs = await signup_and_verify(client, mail, email="theirs@example.com")

    await client.post(
        f"{API}/progress/sync",
        json={"lektionen": [_lektion(xp=55)]},
        headers=auth_header(mine),
    )
    resp = await client.get(f"{API}/progress", headers=auth_header(theirs))
    assert resp.json()["lektionen"] == []
    assert resp.json()["stats"]["total_xp"] == 0


async def test_due_reviews_lists_only_elapsed_items(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="due@example.com")
    headers = auth_header(auth)

    past = _attempt("att-past")
    past["due_at"] = "2026-01-01T00:00:00Z"
    future = _attempt("att-future")
    future["exercise_id"] = "a1.1.m1.l1.wortschatz.flash.099"
    future["due_at"] = "2099-01-01T00:00:00Z"

    await client.post(
        f"{API}/progress/sync",
        json={"attempts": [past, future]},
        headers=headers,
    )
    resp = await client.get(f"{API}/progress/due-reviews", headers=headers)
    assert resp.status_code == 200
    ids = [r["exercise_id"] for r in resp.json()]
    assert ids == ["a1.1.m1.l1.wortschatz.flash.003"]


async def test_deleting_the_account_removes_its_progress(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="wipe@example.com")
    headers = auth_header(auth)
    await client.post(
        f"{API}/progress/sync",
        json={"lektionen": [_lektion()], "attempts": [_attempt("att-wipe")]},
        headers=headers,
    )
    gone = await client.request(
        "DELETE",
        f"{API}/auth/me",
        json={"password": GOOD_PASSWORD, "confirm": True},
        headers=headers,
    )
    assert gone.status_code == 204

    # Same address, brand-new account: no leftovers.
    again = await signup_and_verify(client, mail, email="wipe@example.com")
    resp = await client.get(f"{API}/progress", headers=auth_header(again))
    assert resp.json()["lektionen"] == []
    assert resp.json()["stats"]["total_xp"] == 0
