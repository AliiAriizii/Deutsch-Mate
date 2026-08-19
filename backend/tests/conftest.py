"""Test harness.

Runs against a real mongod (the local service) but in a throwaway database that
is dropped before every test, so tests never touch dev data.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app import mail as mail_module
from app.config import settings
from app.db import connect, disconnect
from app.main import create_app
from app.routers import auth as auth_router

TEST_DB = "deutschmate_test"
API = "/api/v1"


@pytest.fixture(scope="session", autouse=True)
def _point_at_test_db() -> None:
    settings.mongodb_db = TEST_DB
    settings.app_env = "test"
    settings.mail_backend = "console"


class MailSpy:
    """Captures what would have been emailed, so tests can follow the real
    verification / reset flow instead of reaching into the database."""

    def __init__(self) -> None:
        self.verifications: list[dict[str, str]] = []
        self.resets: list[dict[str, str]] = []

    async def send_verification_email(
        self, *, to: str, display_name: str, token: str
    ) -> None:
        self.verifications.append({"to": to, "name": display_name, "token": token})

    async def send_password_reset_email(
        self, *, to: str, display_name: str, code: str
    ) -> None:
        self.resets.append({"to": to, "name": display_name, "code": code})

    def last_token_for(self, email: str) -> str:
        for entry in reversed(self.verifications):
            if entry["to"].lower() == email.lower():
                return entry["token"]
        raise AssertionError(f"no verification mail captured for {email}")

    def last_code_for(self, email: str) -> str:
        for entry in reversed(self.resets):
            if entry["to"].lower() == email.lower():
                return entry["code"]
        raise AssertionError(f"no reset mail captured for {email}")


@pytest.fixture
def mail(monkeypatch: pytest.MonkeyPatch) -> MailSpy:
    spy = MailSpy()
    monkeypatch.setattr(
        auth_router, "send_verification_email", spy.send_verification_email
    )
    monkeypatch.setattr(
        auth_router, "send_password_reset_email", spy.send_password_reset_email
    )
    monkeypatch.setattr(
        mail_module, "send_verification_email", spy.send_verification_email
    )
    return spy


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    mongo = await connect(db_name=TEST_DB)
    await mongo.drop_database(TEST_DB)
    # Re-register indexes on the fresh database.
    await disconnect()
    mongo = await connect(db_name=TEST_DB)

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac

    await disconnect()


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

GOOD_PASSWORD = "Lektion7Blau"


async def signup(
    client: AsyncClient,
    *,
    email: str = "lernerin@example.com",
    password: str = GOOD_PASSWORD,
    name: str = "Test Lernerin",
) -> dict:
    resp = await client.post(
        f"{API}/auth/signup",
        json={"email": email, "password": password, "display_name": name},
    )
    return {"status": resp.status_code, "body": resp.json()}


async def signup_and_verify(
    client: AsyncClient,
    mail: MailSpy,
    *,
    email: str = "lernerin@example.com",
    password: str = GOOD_PASSWORD,
) -> dict:
    """Full happy path: sign up -> follow the emailed token -> tokens in hand."""
    created = await signup(client, email=email, password=password)
    assert created["status"] == 201, created
    token = mail.last_token_for(email)
    resp = await client.post(f"{API}/auth/verify-email", json={"token": token})
    assert resp.status_code == 200, resp.text
    return resp.json()


def auth_header(auth_result: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {auth_result['tokens']['access_token']}"}
