"""Refresh sessions.

Refresh tokens are opaque random strings, never JWTs, and only their SHA-256
fingerprint is stored. Each use rotates the token: the old row is revoked and a
new one issued, so a stolen token stops working the moment the real client
refreshes.
"""

from __future__ import annotations

from datetime import datetime

from beanie import Document, PydanticObjectId
from pydantic import Field
from pymongo import ASCENDING, IndexModel

from ..security import now


class RefreshSession(Document):
    user_id: PydanticObjectId
    token_fingerprint: str
    expires_at: datetime

    device_id: str | None = None
    user_agent: str | None = None

    created_at: datetime = Field(default_factory=now)
    last_used_at: datetime | None = None
    revoked_at: datetime | None = None
    revoked_reason: str | None = None
    # Set when this session was rotated, pointing at its successor. Reuse of a
    # rotated token is the classic replay signal.
    replaced_by: PydanticObjectId | None = None

    class Settings:
        name = "refresh_sessions"
        indexes = [
            IndexModel(
                [("token_fingerprint", ASCENDING)],
                unique=True,
                name="uq_refresh_fingerprint",
            ),
            IndexModel([("user_id", ASCENDING)], name="ix_refresh_user"),
            # Mongo reaps expired sessions on its own; no cron needed.
            IndexModel(
                [("expires_at", ASCENDING)],
                expireAfterSeconds=0,
                name="ttl_refresh_expires",
            ),
        ]

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None and self.expires_at > now()

    def revoke(self, reason: str) -> None:
        self.revoked_at = now()
        self.revoked_reason = reason
