"""Single-use tokens for email verification and password reset."""

from __future__ import annotations

from datetime import datetime

from beanie import Document, PydanticObjectId
from pydantic import Field
from pymongo import ASCENDING, IndexModel

from ..security import now
from .enums import TokenPurpose


class OneTimeToken(Document):
    user_id: PydanticObjectId
    purpose: TokenPurpose
    token_fingerprint: str
    expires_at: datetime

    created_at: datetime = Field(default_factory=now)
    used_at: datetime | None = None
    # Reset codes are short and typed by hand, so they are guessable in bulk
    # unless attempts are bounded.
    attempt_count: int = 0

    class Settings:
        name = "one_time_tokens"
        indexes = [
            IndexModel(
                [("token_fingerprint", ASCENDING), ("purpose", ASCENDING)],
                unique=True,
                name="uq_token_purpose",
            ),
            IndexModel(
                [("user_id", ASCENDING), ("purpose", ASCENDING)],
                name="ix_token_user_purpose",
            ),
            IndexModel(
                [("expires_at", ASCENDING)],
                expireAfterSeconds=0,
                name="ttl_token_expires",
            ),
        ]

    @property
    def is_usable(self) -> bool:
        return self.used_at is None and self.expires_at > now()
