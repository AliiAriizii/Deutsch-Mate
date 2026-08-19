"""Shared FastAPI dependencies."""

from __future__ import annotations

from typing import Annotated

from beanie import PydanticObjectId
from fastapi import Depends, Header

from .config import settings
from .errors import ErrorCode, Unauthorized
from .models.enums import UserStatus
from .models.user import User
from .security import decode_access_token


async def _bearer_token(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    if not authorization:
        raise Unauthorized(
            "Authorization header is missing.", code=ErrorCode.AUTH_TOKEN_MISSING
        )
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise Unauthorized(
            "Authorization header must be 'Bearer <token>'.",
            code=ErrorCode.AUTH_TOKEN_INVALID,
        )
    return token.strip()


async def current_user(token: Annotated[str, Depends(_bearer_token)]) -> User:
    payload = decode_access_token(token)
    try:
        user_id = PydanticObjectId(payload["sub"])
    except Exception as exc:  # malformed subject
        raise Unauthorized(
            "Token subject is not a valid user id.", code=ErrorCode.AUTH_TOKEN_INVALID
        ) from exc

    user = await User.get(user_id)
    if user is None:
        raise Unauthorized(
            "The account for this token no longer exists.",
            code=ErrorCode.AUTH_TOKEN_INVALID,
        )
    if user.status is not UserStatus.ACTIVE:
        raise Unauthorized(
            "This account is disabled.", code=ErrorCode.AUTH_ACCOUNT_DISABLED
        )
    return user


async def verified_user(
    user: Annotated[User, Depends(current_user)],
) -> User:
    """For endpoints that must not run on an unverified account."""
    if settings.email_verification_required and not user.email_verified:
        raise Unauthorized(
            "Confirm your email address to continue.",
            code=ErrorCode.AUTH_EMAIL_NOT_VERIFIED,
        )
    return user


CurrentUser = Annotated[User, Depends(current_user)]
VerifiedUser = Annotated[User, Depends(verified_user)]
