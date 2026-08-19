"""Auth flow: the failures the old client-side implementation got wrong."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from .conftest import API, GOOD_PASSWORD, MailSpy, auth_header, signup, signup_and_verify

pytestmark = pytest.mark.asyncio


async def test_password_policy_is_published(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/auth/password-policy")
    assert resp.status_code == 200
    body = resp.json()
    assert body["min_length"] >= 10
    assert "requires_digit" in body["rule_ids"]


async def test_signup_requires_verification_and_issues_no_tokens(
    client: AsyncClient, mail: MailSpy
) -> None:
    result = await signup(client)
    assert result["status"] == 201
    assert result["body"]["email_verification_required"] is True
    # Nothing to persist yet - no half-authenticated state.
    assert result["body"]["tokens"] is None
    assert len(mail.verifications) == 1


async def test_weak_password_is_rejected_with_violations(client: AsyncClient) -> None:
    resp = await client.post(
        f"{API}/auth/signup",
        json={"email": "weak@example.com", "password": "short", "display_name": "W"},
    )
    assert resp.status_code == 400
    err = resp.json()["error"]
    assert err["code"] == "AUTH_WEAK_PASSWORD"
    assert "min_length" in err["details"]["violations"]
    assert "requires_digit" in err["details"]["violations"]


async def test_common_password_is_rejected(client: AsyncClient) -> None:
    resp = await client.post(
        f"{API}/auth/signup",
        json={
            "email": "common@example.com",
            "password": "password123",
            "display_name": "C",
        },
    )
    assert resp.status_code == 400
    assert "not_common" in resp.json()["error"]["details"]["violations"]


async def test_duplicate_email_conflicts_case_insensitively(
    client: AsyncClient, mail: MailSpy
) -> None:
    first = await signup(client, email="Doppel@Example.com")
    assert first["status"] == 201
    second = await signup(client, email="doppel@example.com")
    assert second["status"] == 409
    assert second["body"]["error"]["code"] == "AUTH_EMAIL_TAKEN"


async def test_double_tapped_signup_creates_one_account(
    client: AsyncClient, mail: MailSpy
) -> None:
    """The bug the old client had: two taps, two writes."""
    a = await signup(client, email="tap@example.com")
    b = await signup(client, email="tap@example.com")
    assert a["status"] == 201
    assert b["status"] == 409


async def test_signin_before_verification_is_refused(
    client: AsyncClient, mail: MailSpy
) -> None:
    await signup(client, email="unverified@example.com")
    resp = await client.post(
        f"{API}/auth/signin",
        json={"email": "unverified@example.com", "password": GOOD_PASSWORD},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_EMAIL_NOT_VERIFIED"


async def test_wrong_password_never_authenticates(
    client: AsyncClient, mail: MailSpy
) -> None:
    """The old client logged anyone in with any password."""
    await signup_and_verify(client, mail, email="real@example.com")
    resp = await client.post(
        f"{API}/auth/signin",
        json={"email": "real@example.com", "password": "TotallyWrong9"},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_INVALID_CREDENTIALS"


async def test_unknown_email_is_indistinguishable_from_wrong_password(
    client: AsyncClient,
) -> None:
    resp = await client.post(
        f"{API}/auth/signin",
        json={"email": "ghost@example.com", "password": GOOD_PASSWORD},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_INVALID_CREDENTIALS"


async def test_verify_then_signin_then_me(client: AsyncClient, mail: MailSpy) -> None:
    verified = await signup_and_verify(client, mail, email="happy@example.com")
    assert verified["user"]["email_verified"] is True
    assert verified["tokens"]["access_token"]

    signed_in = await client.post(
        f"{API}/auth/signin",
        json={"email": "happy@example.com", "password": GOOD_PASSWORD},
    )
    assert signed_in.status_code == 200

    me = await client.get(f"{API}/auth/me", headers=auth_header(signed_in.json()))
    assert me.status_code == 200
    assert me.json()["email"] == "happy@example.com"


async def test_verification_token_is_single_use(
    client: AsyncClient, mail: MailSpy
) -> None:
    await signup(client, email="once@example.com")
    token = mail.last_token_for("once@example.com")
    first = await client.post(f"{API}/auth/verify-email", json={"token": token})
    assert first.status_code == 200
    second = await client.post(f"{API}/auth/verify-email", json={"token": token})
    assert second.status_code == 400
    assert second.json()["error"]["code"] == "AUTH_VERIFY_TOKEN_INVALID"


async def test_missing_bearer_token_is_typed(client: AsyncClient) -> None:
    resp = await client.get(f"{API}/auth/me")
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_TOKEN_MISSING"


async def test_garbage_bearer_token_is_typed(client: AsyncClient) -> None:
    resp = await client.get(
        f"{API}/auth/me", headers={"Authorization": "Bearer not-a-jwt"}
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_TOKEN_INVALID"


async def test_refresh_rotates_and_old_token_dies(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="rotate@example.com")
    old_refresh = auth["tokens"]["refresh_token"]

    first = await client.post(f"{API}/auth/refresh", json={"refresh_token": old_refresh})
    assert first.status_code == 200
    new_refresh = first.json()["refresh_token"]
    assert new_refresh != old_refresh

    replay = await client.post(f"{API}/auth/refresh", json={"refresh_token": old_refresh})
    assert replay.status_code == 401
    assert replay.json()["error"]["code"] == "AUTH_REFRESH_REVOKED"

    # Replay detection killed the whole family, successor included.
    after = await client.post(f"{API}/auth/refresh", json={"refresh_token": new_refresh})
    assert after.status_code == 401


async def test_logout_invalidates_the_session(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="bye@example.com")
    refresh = auth["tokens"]["refresh_token"]

    out = await client.post(
        f"{API}/auth/logout",
        json={"refresh_token": refresh},
        headers=auth_header(auth),
    )
    assert out.status_code == 200

    resp = await client.post(f"{API}/auth/refresh", json={"refresh_token": refresh})
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_REFRESH_REVOKED"


async def test_forgot_password_does_not_leak_account_existence(
    client: AsyncClient, mail: MailSpy
) -> None:
    known = await client.post(
        f"{API}/auth/forgot-password", json={"email": "nobody@example.com"}
    )
    assert known.status_code == 200
    assert known.json()["ok"] is True
    assert mail.resets == []


async def test_password_reset_end_to_end(client: AsyncClient, mail: MailSpy) -> None:
    auth = await signup_and_verify(client, mail, email="reset@example.com")
    old_refresh = auth["tokens"]["refresh_token"]

    await client.post(f"{API}/auth/forgot-password", json={"email": "reset@example.com"})
    code = mail.last_code_for("reset@example.com")

    done = await client.post(
        f"{API}/auth/reset-password",
        json={
            "email": "reset@example.com",
            "code": code,
            "new_password": "NeuesPasswort7",
        },
    )
    assert done.status_code == 200

    # Old password no longer works, new one does.
    old = await client.post(
        f"{API}/auth/signin",
        json={"email": "reset@example.com", "password": GOOD_PASSWORD},
    )
    assert old.status_code == 401
    new = await client.post(
        f"{API}/auth/signin",
        json={"email": "reset@example.com", "password": "NeuesPasswort7"},
    )
    assert new.status_code == 200

    # And every pre-reset session is dead.
    stale = await client.post(f"{API}/auth/refresh", json={"refresh_token": old_refresh})
    assert stale.status_code == 401


async def test_reset_code_cannot_be_redeemed_by_another_account(
    client: AsyncClient, mail: MailSpy
) -> None:
    await signup_and_verify(client, mail, email="victim@example.com")
    await signup_and_verify(client, mail, email="attacker@example.com")

    await client.post(f"{API}/auth/forgot-password", json={"email": "victim@example.com"})
    victim_code = mail.last_code_for("victim@example.com")

    resp = await client.post(
        f"{API}/auth/reset-password",
        json={
            "email": "attacker@example.com",
            "code": victim_code,
            "new_password": "Uebernahme9",
        },
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "AUTH_RESET_TOKEN_INVALID"


async def test_reset_code_is_single_use(client: AsyncClient, mail: MailSpy) -> None:
    await signup_and_verify(client, mail, email="onceonly@example.com")
    await client.post(
        f"{API}/auth/forgot-password", json={"email": "onceonly@example.com"}
    )
    code = mail.last_code_for("onceonly@example.com")
    body = {
        "email": "onceonly@example.com",
        "code": code,
        "new_password": "ErsterVersuch1",
    }
    assert (await client.post(f"{API}/auth/reset-password", json=body)).status_code == 200
    body["new_password"] = "ZweiterVersuch2"
    second = await client.post(f"{API}/auth/reset-password", json=body)
    assert second.status_code == 400


async def test_account_locks_after_repeated_failures(
    client: AsyncClient, mail: MailSpy
) -> None:
    await signup_and_verify(client, mail, email="brute@example.com")
    for _ in range(10):
        resp = await client.post(
            f"{API}/auth/signin",
            json={"email": "brute@example.com", "password": "WrongOne1"},
        )
        assert resp.status_code == 401

    locked = await client.post(
        f"{API}/auth/signin",
        json={"email": "brute@example.com", "password": GOOD_PASSWORD},
    )
    assert locked.status_code == 429
    err = locked.json()["error"]
    assert err["code"] == "AUTH_ACCOUNT_LOCKED"
    assert err["details"]["retry_after_seconds"] > 0


async def test_onboarding_persists_and_seeds_placement(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="onboard@example.com")
    assert auth["user"]["onboarding"]["completed"] is False

    resp = await client.post(
        f"{API}/auth/onboarding",
        json={
            "target_level": "B1.1",
            "daily_goal_minutes": 20,
            "interface_language": "fa",
        },
        headers=auth_header(auth),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["onboarding"]["completed"] is True
    assert body["onboarding"]["target_level"] == "B1.1"
    # Someone starting at B1.1 must not be walked through A1.1.
    assert body["placement_level"] == "B1.1"


async def test_onboarding_rejects_out_of_range_goal(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="goal@example.com")
    resp = await client.post(
        f"{API}/auth/onboarding",
        json={
            "target_level": "A1.1",
            "daily_goal_minutes": 9999,
            "interface_language": "en",
        },
        headers=auth_header(auth),
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "VALIDATION_ERROR"
    assert "daily_goal_minutes" in resp.json()["error"]["details"]["fields"]


async def test_change_password_requires_current_password(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="change@example.com")
    resp = await client.post(
        f"{API}/auth/change-password",
        json={"current_password": "NotIt1234", "new_password": "AndererWert3"},
        headers=auth_header(auth),
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_INVALID_CREDENTIALS"


async def test_delete_account_requires_password_and_confirmation(
    client: AsyncClient, mail: MailSpy
) -> None:
    auth = await signup_and_verify(client, mail, email="delete@example.com")
    headers = auth_header(auth)

    unconfirmed = await client.request(
        "DELETE",
        f"{API}/auth/me",
        json={"password": GOOD_PASSWORD, "confirm": False},
        headers=headers,
    )
    assert unconfirmed.status_code == 400

    wrong_pw = await client.request(
        "DELETE",
        f"{API}/auth/me",
        json={"password": "NichtMeins1", "confirm": True},
        headers=headers,
    )
    assert wrong_pw.status_code == 401

    gone = await client.request(
        "DELETE",
        f"{API}/auth/me",
        json={"password": GOOD_PASSWORD, "confirm": True},
        headers=headers,
    )
    assert gone.status_code == 204

    # The account is really gone, and the old token no longer resolves.
    after = await client.get(f"{API}/auth/me", headers=headers)
    assert after.status_code == 401

    resignup = await signup(client, email="delete@example.com")
    assert resignup["status"] == 201
