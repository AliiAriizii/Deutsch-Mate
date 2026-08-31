"""User document."""

from __future__ import annotations

from datetime import datetime

from beanie import Document
from pydantic import BaseModel, EmailStr, Field
from pymongo import ASCENDING, IndexModel

from ..security import now
from .enums import AuthProvider, CefrLevel, InterfaceLanguage, UserStatus


class OnboardingProfile(BaseModel):
    """Captured right after sign-up; drives the start position in the content
    tree and the daily-goal ring."""

    target_level: CefrLevel | None = None
    daily_goal_minutes: int | None = Field(default=None, ge=5, le=240)
    interface_language: InterfaceLanguage | None = None
    completed: bool = False
    completed_at: datetime | None = None


class FederatedIdentity(BaseModel):
    """One provider account bound to this user.

    Keyed on `subject` - the provider's stable id for the person - never on the
    email address. Apple's "Hide My Email" hands out a relay address that can
    differ from the real one, and Google addresses can be reassigned inside a
    Workspace domain; the subject is the only thing that does not move.
    """

    provider: AuthProvider
    subject: str
    email: str | None = None
    linked_at: datetime = Field(default_factory=now)


class User(Document):
    # `email` keeps the address as typed; `email_key` is the lowercased form and
    # carries the unique index, so Foo@x.com and foo@x.com cannot both exist.
    email: EmailStr
    email_key: str
    # None for accounts created purely through a provider - there is no
    # password to verify, and a blank string would be a silent auth bypass.
    password_hash: str | None = None
    display_name: str
    phone: str | None = None

    email_verified: bool = False
    email_verified_at: datetime | None = None
    status: UserStatus = UserStatus.ACTIVE

    # Every way this person can sign in. A password-only account has an empty
    # list; a Google-only account has no password_hash.
    identities: list[FederatedIdentity] = Field(default_factory=list)

    onboarding: OnboardingProfile = Field(default_factory=OnboardingProfile)

    # Placement: the Lektion the user is dropped at, so someone starting at
    # B1.1 never walks through A1.1.
    placement_level: CefrLevel | None = None
    placement_source: str | None = None  # "test" | "manual" | "default"

    failed_login_count: int = 0
    locked_until: datetime | None = None

    created_at: datetime = Field(default_factory=now)
    updated_at: datetime = Field(default_factory=now)
    last_login_at: datetime | None = None

    class Settings:
        name = "users"
        indexes = [
            IndexModel([("email_key", ASCENDING)], unique=True, name="uq_email_key"),
            IndexModel([("status", ASCENDING)], name="ix_status"),
            IndexModel(
                [("identities.provider", ASCENDING), ("identities.subject", ASCENDING)],
                name="ix_identity",
            ),
        ]

    @staticmethod
    def normalize_email(email: str) -> str:
        return email.strip().lower()

    def identity_for(self, provider: AuthProvider) -> FederatedIdentity | None:
        return next((i for i in self.identities if i.provider is provider), None)

    @property
    def has_password(self) -> bool:
        return bool(self.password_hash)

    @property
    def is_locked(self) -> bool:
        return self.locked_until is not None and self.locked_until > now()

    def touch(self) -> None:
        self.updated_at = now()
