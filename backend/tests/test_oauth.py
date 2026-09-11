"""Federated sign-in.

These tests mint their own RSA key, sign tokens with it, and point the verifier
at the matching public key - so the full verification path runs for real
(RS256 signature, aud, iss, exp, nonce) without touching Google.

The forgery tests are the point of the file: a token this server did not ask
for must not authenticate anybody.
"""

from __future__ import annotations

import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from httpx import AsyncClient

from app.config import settings
from app.services import oauth

from .conftest import API, GOOD_PASSWORD, MailSpy, auth_header, signup, signup_and_verify

pytestmark = pytest.mark.asyncio

# Grabbed at import time, before the autouse fixture swaps it out.
_REAL_SIGNING_KEY = oauth._signing_key

WEB_CLIENT_ID = "111-web.apps.googleusercontent.com"
ANDROID_CLIENT_ID = "111-android.apps.googleusercontent.com"


@pytest.fixture(scope="session")
def signing_key() -> rsa.RSAPrivateKey:
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture(autouse=True)
def google_configured(
    monkeypatch: pytest.MonkeyPatch, signing_key: rsa.RSAPrivateKey
) -> None:
    """Configure the provider and redirect key lookup to our test key."""
    monkeypatch.setattr(
        settings, "google_client_ids", f"{WEB_CLIENT_ID},{ANDROID_CLIENT_ID}"
    )
    monkeypatch.setattr(
        oauth, "_signing_key", lambda jwks_url, token: signing_key.public_key()
    )


def google_token(
    signing_key: rsa.RSAPrivateKey,
    *,
    sub: str = "google-sub-1",
    email: str | None = "lernerin@example.com",
    email_verified: bool | str = True,
    aud: str = WEB_CLIENT_ID,
    iss: str = "https://accounts.google.com",
    name: str | None = "Test Lernerin",
    nonce: str | None = None,
    expires_in: int = 600,
) -> str:
    issued = int(time.time())
    payload: dict[str, object] = {
        "iss": iss,
        "aud": aud,
        "sub": sub,
        "iat": issued,
        "exp": issued + expires_in,
    }
    if email is not None:
        payload["email"] = email
        payload["email_verified"] = email_verified
    if name is not None:
        payload["name"] = name
    if nonce is not None:
        payload["nonce"] = nonce
    return jwt.encode(payload, signing_key, algorithm="RS256")


# --------------------------------------------------------------------------- #
# forgery and misuse
# --------------------------------------------------------------------------- #


async def test_a_client_cannot_just_claim_an_identity(client: AsyncClient) -> None:
    """No email or user id is accepted from the client - only a signed token."""
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"email": "victim@example.com", "sub": "whatever"},
    )
    assert resp.status_code == 422


async def test_token_signed_by_the_wrong_key_is_refused(
    client: AsyncClient,
) -> None:
    attacker_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    forged = google_token(attacker_key, email="victim@example.com")

    resp = await client.post(f"{API}/auth/oauth/google", json={"id_token": forged})
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_TOKEN_INVALID"


async def test_unsigned_token_is_refused(client: AsyncClient) -> None:
    # The classic alg=none downgrade.
    issued = int(time.time())
    unsigned = jwt.encode(
        {
            "iss": "https://accounts.google.com",
            "aud": WEB_CLIENT_ID,
            "sub": "x",
            "iat": issued,
            "exp": issued + 600,
            "email": "victim@example.com",
            "email_verified": True,
        },
        key="",
        algorithm="none",
    )
    resp = await client.post(f"{API}/auth/oauth/google", json={"id_token": unsigned})
    assert resp.status_code == 401


async def test_token_for_another_app_is_refused(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """A genuine Google token minted for a different product, replayed here."""
    other_app = google_token(signing_key, aud="999-someone-else.apps.googleusercontent.com")
    resp = await client.post(f"{API}/auth/oauth/google", json={"id_token": other_app})
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_TOKEN_INVALID"


async def test_wrong_issuer_is_refused(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, iss="https://evil.example.com")},
    )
    assert resp.status_code == 401


async def test_expired_token_is_refused(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, expires_in=-3600)},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_TOKEN_EXPIRED"


async def test_unverified_google_email_is_refused(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email_verified=False)},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_PROVIDER_EMAIL_UNVERIFIED"


async def test_provider_disabled_when_no_client_ids_configured(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "google_client_ids", "")
    resp = await client.post(
        f"{API}/auth/oauth/google", json={"id_token": google_token(signing_key)}
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_PROVIDER_NOT_CONFIGURED"


async def test_nonce_mismatch_is_refused(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """Binds the token to this attempt, so one captured elsewhere cannot be
    replayed."""
    token = google_token(signing_key, nonce="hash-of-some-other-attempt")
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": token, "nonce": "the-nonce-this-attempt-generated"},
    )
    assert resp.status_code == 401


async def test_nonce_accepted_as_sha256_of_the_raw_value(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    import hashlib

    raw = "attempt-nonce-abc"
    token = google_token(
        signing_key, nonce=hashlib.sha256(raw.encode()).hexdigest()
    )
    resp = await client.post(
        f"{API}/auth/oauth/google", json={"id_token": token, "nonce": raw}
    )
    assert resp.status_code == 200


# --------------------------------------------------------------------------- #
# happy paths
# --------------------------------------------------------------------------- #


async def test_first_google_signin_creates_a_verified_account(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email="neu@example.com")},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()

    # Google asserted the address, so no second verification email is needed.
    assert body["user"]["email_verified"] is True
    assert body["user"]["email"] == "neu@example.com"
    assert body["user"]["has_password"] is False
    assert [i["provider"] for i in body["user"]["identities"]] == ["google"]
    assert body["tokens"]["access_token"]


async def test_second_google_signin_reuses_the_same_account(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    token = google_token(signing_key, email="wieder@example.com")
    first = await client.post(f"{API}/auth/oauth/google", json={"id_token": token})
    second = await client.post(f"{API}/auth/oauth/google", json={"id_token": token})

    assert first.status_code == second.status_code == 200
    assert first.json()["user"]["id"] == second.json()["user"]["id"]


async def test_google_identity_survives_an_email_change_at_google(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """Identity is keyed on `sub`, not the address, so a Workspace rename does
    not orphan the account."""
    first = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, sub="stable-1", email="old@example.com")},
    )
    renamed = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, sub="stable-1", email="new@example.com")},
    )
    assert first.json()["user"]["id"] == renamed.json()["user"]["id"]


async def test_tokens_from_the_android_client_id_are_accepted(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """Android, iOS and web each have their own client id and all are us."""
    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, aud=ANDROID_CLIENT_ID)},
    )
    assert resp.status_code == 200


async def test_google_account_can_use_the_whole_api(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """A provider-only account is a first-class account, not a special case."""
    auth = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email="voll@example.com")},
    )
    headers = auth_header(auth.json())

    me = await client.get(f"{API}/auth/me", headers=headers)
    assert me.status_code == 200

    onboarding = await client.post(
        f"{API}/auth/onboarding",
        json={
            "target_level": "A1.1",
            "daily_goal_minutes": 20,
            "interface_language": "fa",
        },
        headers=headers,
    )
    assert onboarding.status_code == 200

    progress = await client.get(f"{API}/progress", headers=headers)
    assert progress.status_code == 200


# --------------------------------------------------------------------------- #
# linking - the case most implementations get wrong
# --------------------------------------------------------------------------- #


async def test_google_on_an_existing_password_email_does_not_take_over(
    client: AsyncClient, mail: MailSpy, signing_key: rsa.RSAPrivateKey
) -> None:
    """The whole point: a Google token for an address that already has a
    password account must NOT silently sign you in as that user."""
    await signup_and_verify(client, mail, email="beides@example.com")

    resp = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email="beides@example.com")},
    )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "AUTH_LINK_REQUIRES_PASSWORD"


async def test_linking_with_the_password_joins_one_account(
    client: AsyncClient, mail: MailSpy, signing_key: rsa.RSAPrivateKey
) -> None:
    original = await signup_and_verify(client, mail, email="verbunden@example.com")

    linked = await client.post(
        f"{API}/auth/oauth/google/link",
        json={
            "id_token": google_token(signing_key, email="verbunden@example.com"),
            "password": GOOD_PASSWORD,
        },
    )
    assert linked.status_code == 200, linked.text

    # Same account, now reachable both ways.
    assert linked.json()["user"]["id"] == original["user"]["id"]
    assert linked.json()["user"]["has_password"] is True
    assert [i["provider"] for i in linked.json()["user"]["identities"]] == ["google"]

    # And Google alone works from now on - no second account appears.
    again = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email="verbunden@example.com")},
    )
    assert again.status_code == 200
    assert again.json()["user"]["id"] == original["user"]["id"]

    # The password still works too.
    pw = await client.post(
        f"{API}/auth/signin",
        json={"email": "verbunden@example.com", "password": GOOD_PASSWORD},
    )
    assert pw.status_code == 200
    assert pw.json()["user"]["id"] == original["user"]["id"]


async def test_linking_with_the_wrong_password_is_refused(
    client: AsyncClient, mail: MailSpy, signing_key: rsa.RSAPrivateKey
) -> None:
    await signup_and_verify(client, mail, email="falsch@example.com")

    resp = await client.post(
        f"{API}/auth/oauth/google/link",
        json={
            "id_token": google_token(signing_key, email="falsch@example.com"),
            "password": "NichtDasPasswort9",
        },
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_INVALID_CREDENTIALS"


async def test_signing_up_with_an_email_already_used_by_google_conflicts(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """The reverse direction: Google first, then someone tries email signup."""
    await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email="zuerst@example.com")},
    )
    resp = await signup(client, email="zuerst@example.com")
    assert resp["status"] == 409
    assert resp["body"]["error"]["code"] == "AUTH_EMAIL_TAKEN"


async def test_password_signin_on_a_google_only_account_says_so(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """Without this the user faces a password that is permanently 'wrong'.

    It reveals that the address is registered - but signup's AUTH_EMAIL_TAKEN
    already reveals exactly that, so it is not a new disclosure.
    """
    await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, email="nurgoogle@example.com")},
    )
    resp = await client.post(
        f"{API}/auth/signin",
        json={"email": "nurgoogle@example.com", "password": GOOD_PASSWORD},
    )
    assert resp.status_code == 401
    err = resp.json()["error"]
    assert err["code"] == "AUTH_USE_PROVIDER_SIGNIN"
    assert err["details"]["providers"] == ["google"]


async def test_google_only_account_cannot_be_deleted_without_reauth(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    """A stolen access token alone must not destroy an account."""
    token = google_token(signing_key, email="loeschen@example.com")
    auth = await client.post(f"{API}/auth/oauth/google", json={"id_token": token})
    headers = auth_header(auth.json())

    refused = await client.request(
        "DELETE", f"{API}/auth/me", json={"confirm": True}, headers=headers
    )
    assert refused.status_code == 401
    assert refused.json()["error"]["code"] == "AUTH_USE_PROVIDER_SIGNIN"

    # With a fresh provider token it goes through.
    gone = await client.request(
        "DELETE",
        f"{API}/auth/me",
        json={"confirm": True, "id_token": token},
        headers=headers,
    )
    assert gone.status_code == 204


async def test_deleting_with_another_persons_google_token_is_refused(
    client: AsyncClient, signing_key: rsa.RSAPrivateKey
) -> None:
    mine = await client.post(
        f"{API}/auth/oauth/google",
        json={"id_token": google_token(signing_key, sub="me", email="meins@example.com")},
    )
    headers = auth_header(mine.json())

    someone_else = google_token(
        signing_key, sub="them", email="fremd@example.com"
    )
    resp = await client.request(
        "DELETE",
        f"{API}/auth/me",
        json={"confirm": True, "id_token": someone_else},
        headers=headers,
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "AUTH_INVALID_CREDENTIALS"


# --------------------------------------------------------------------------- #
# the real key-resolution path
#
# Every test above monkeypatches _signing_key, which is what let a bug through:
# a malformed token raises a PyJWT decode error inside
# get_signing_key_from_jwt, that was not caught, and the endpoint answered 500.
# These exercise the genuine function with no patching.
# --------------------------------------------------------------------------- #


async def test_a_malformed_token_is_401_not_500(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Garbage in the id_token field must not crash the endpoint.

    This is exactly what a curl probe sent, and it returned Internal Server
    Error before the fix.
    """
    monkeypatch.setattr(oauth, "_signing_key", _REAL_SIGNING_KEY)

    for junk in ["not-a-real-token", "", "a.b", "....", "Bearer something"]:
        resp = await client.post(
            f"{API}/auth/oauth/google", json={"id_token": junk or "x"}
        )
        assert resp.status_code == 401, f"{junk!r} produced {resp.status_code}"
        assert resp.json()["error"]["code"] in {
            "AUTH_TOKEN_INVALID",
            "AUTH_PROVIDER_UNAVAILABLE",
        }


async def test_a_token_with_an_unknown_kid_is_401_not_500(
    client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
    signing_key: rsa.RSAPrivateKey,
) -> None:
    """Structurally valid, signed by a key Google never published."""
    monkeypatch.setattr(oauth, "_signing_key", _REAL_SIGNING_KEY)

    token = jwt.encode(
        {"iss": "https://accounts.google.com", "aud": WEB_CLIENT_ID, "sub": "x",
         "iat": int(time.time()), "exp": int(time.time()) + 600},
        signing_key,
        algorithm="RS256",
        headers={"kid": "a-kid-google-never-issued"},
    )

    # This one reaches Google's JWKS endpoint for real, so it accepts either
    # verdict: TOKEN_INVALID when the fetch succeeds and the kid is absent,
    # PROVIDER_UNAVAILABLE when the machine is offline. Both are 401, which is
    # the property under test.
    resp = await client.post(f"{API}/auth/oauth/google", json={"id_token": token})
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] in {
        "AUTH_TOKEN_INVALID",
        "AUTH_PROVIDER_UNAVAILABLE",
    }
