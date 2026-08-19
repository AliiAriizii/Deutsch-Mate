"""Password hashing, password policy, JWT access tokens, opaque refresh tokens."""

from __future__ import annotations

import hashlib
import secrets
import string
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from .config import settings
from .errors import ErrorCode, Unauthorized

_hasher = PasswordHasher()

# Rejected outright regardless of length rules. Deliberately short list - real
# breach-corpus checking belongs behind a service, not in the repo.
_COMMON_PASSWORDS = frozenset(
    {
        "password",
        "password1",
        "password123",
        "12345678",
        "123456789",
        "1234567890",
        "qwertyuiop",
        "qwerty123",
        "iloveyou",
        "adminadmin",
        "letmein123",
        "deutschmate",
        "deutsch123",
        "passwort",
        "passwort123",
    }
)


def now() -> datetime:
    return datetime.now(UTC)


# --------------------------------------------------------------------------- #
# password policy
# --------------------------------------------------------------------------- #


def password_policy() -> dict[str, Any]:
    """Machine-readable rules.

    Served to the client so the app can state the rules *before* the user types,
    from the same source the server enforces.
    """
    return {
        "min_length": settings.password_min_length,
        "max_length": settings.password_max_length,
        "require_letter": settings.password_require_letter,
        "require_digit": settings.password_require_digit,
        "rejects_common_passwords": True,
        "rule_ids": ["min_length", "requires_letter", "requires_digit", "not_common"],
    }


def validate_password(password: str) -> list[str]:
    """Return the list of violated rule ids. Empty list means acceptable."""
    violations: list[str] = []
    if len(password) < settings.password_min_length:
        violations.append("min_length")
    if len(password) > settings.password_max_length:
        violations.append("max_length")
    if settings.password_require_letter and not any(c.isalpha() for c in password):
        violations.append("requires_letter")
    if settings.password_require_digit and not any(c.isdigit() for c in password):
        violations.append("requires_digit")
    if password.strip().lower() in _COMMON_PASSWORDS:
        violations.append("not_common")
    return violations


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        _hasher.verify(password_hash, password)
        return True
    except (VerifyMismatchError, InvalidHashError, ValueError):
        return False


def needs_rehash(password_hash: str) -> bool:
    try:
        return _hasher.check_needs_rehash(password_hash)
    except (InvalidHashError, ValueError):
        return True


# --------------------------------------------------------------------------- #
# access tokens (JWT, short-lived, stateless)
# --------------------------------------------------------------------------- #


def create_access_token(user_id: str, *, email_verified: bool) -> tuple[str, datetime]:
    issued = now()
    expires_at = issued + timedelta(minutes=settings.access_token_ttl_minutes)
    payload = {
        "sub": user_id,
        "typ": "access",
        "ev": email_verified,
        "jti": uuid.uuid4().hex,
        "iat": int(issued.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_at


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["exp", "sub", "typ"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise Unauthorized(
            "Access token has expired.", code=ErrorCode.AUTH_TOKEN_EXPIRED
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise Unauthorized(
            "Access token is not valid.", code=ErrorCode.AUTH_TOKEN_INVALID
        ) from exc

    if payload.get("typ") != "access":
        raise Unauthorized("Wrong token type.", code=ErrorCode.AUTH_TOKEN_INVALID)
    return payload


# --------------------------------------------------------------------------- #
# refresh + one-time tokens (opaque, stored hashed)
# --------------------------------------------------------------------------- #

_TOKEN_ALPHABET = string.ascii_letters + string.digits
_DIGITS = string.digits


def generate_opaque_token(length: int = 48) -> str:
    return "".join(secrets.choice(_TOKEN_ALPHABET) for _ in range(length))


def generate_numeric_code(length: int = 6) -> str:
    """Short code for password reset, typed by hand in the app."""
    return "".join(secrets.choice(_DIGITS) for _ in range(length))


def token_fingerprint(token: str) -> str:
    """SHA-256 of the token.

    Only the fingerprint is persisted, so a database dump does not hand out live
    refresh or reset tokens.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
