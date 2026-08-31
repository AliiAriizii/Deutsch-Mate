"""Request/response bodies for the auth surface."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator

from ..models.enums import CefrLevel, InterfaceLanguage


class SignUpRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)
    display_name: str = Field(min_length=1, max_length=80)
    phone: str | None = Field(default=None, max_length=32)

    @field_validator("display_name")
    @classmethod
    def _strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Display name cannot be blank.")
        return v

    @field_validator("phone")
    @classmethod
    def _clean_phone(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None


class SignInRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)
    device_id: str | None = Field(default=None, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=256)


class LogoutRequest(BaseModel):
    refresh_token: str | None = Field(default=None, max_length=256)
    all_devices: bool = False


class VerifyEmailRequest(BaseModel):
    token: str = Field(min_length=1, max_length=256)


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=16)
    new_password: str = Field(min_length=1, max_length=256)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=256)
    new_password: str = Field(min_length=1, max_length=256)


class ProviderSignInRequest(BaseModel):
    """An ID token minted by the provider for *this* app.

    The client sends no identity of its own - no email, no user id. Everything
    we act on is read out of the verified token.
    """

    id_token: str = Field(min_length=1, max_length=8192)
    # Raw nonce the client generated for this attempt. The provider echoes its
    # SHA-256 into the token, which is what stops a token captured elsewhere
    # from being replayed here.
    nonce: str | None = Field(default=None, max_length=256)
    device_id: str | None = Field(default=None, max_length=128)


class ProviderLinkRequest(ProviderSignInRequest):
    """Attaching a provider to an existing password account.

    Requires the password, because the provider token alone only proves control
    of the provider account - not of the account already registered here.
    """

    password: str = Field(min_length=1, max_length=256)


class DeleteAccountRequest(BaseModel):
    """Store policy requires a real deletion path. Re-auth is required so a
    stolen access token cannot nuke an account."""

    password: str = Field(default="", max_length=256)
    # Provider-only accounts have no password to re-authenticate with, so they
    # prove ownership with a fresh provider token instead.
    id_token: str | None = Field(default=None, max_length=8192)
    confirm: bool = False


class OnboardingRequest(BaseModel):
    target_level: CefrLevel
    daily_goal_minutes: int = Field(ge=5, le=240)
    interface_language: InterfaceLanguage


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_at: datetime
    expires_in: int


class OnboardingOut(BaseModel):
    target_level: CefrLevel | None
    daily_goal_minutes: int | None
    interface_language: InterfaceLanguage | None
    completed: bool


class IdentityOut(BaseModel):
    provider: str
    email: str | None


class UserOut(BaseModel):
    id: str
    email: EmailStr
    display_name: str
    phone: str | None
    email_verified: bool
    status: str
    onboarding: OnboardingOut
    placement_level: CefrLevel | None
    created_at: datetime
    last_login_at: datetime | None
    # What this account can sign in with, so the client can show "connected"
    # state on the profile screen and refuse to unlink the last method.
    identities: list[IdentityOut] = []
    has_password: bool = True


class AuthResult(BaseModel):
    """What the client stores after sign-up or sign-in.

    ``tokens`` is null when the account still needs email verification and
    verification is enforced - the client then routes to the verify screen
    instead of home, with nothing to persist.
    """

    user: UserOut
    tokens: TokenPair | None = None
    email_verification_required: bool = False


class PasswordPolicyOut(BaseModel):
    min_length: int
    max_length: int
    require_letter: bool
    require_digit: bool
    rejects_common_passwords: bool
    rule_ids: list[str]


class MessageOut(BaseModel):
    ok: bool = True
    message: str
