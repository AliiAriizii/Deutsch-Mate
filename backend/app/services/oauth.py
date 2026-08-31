"""Federated identity verification.

The client never tells us who it is. It hands over a provider-issued ID token
and we verify that token against the provider's published signing keys. A client
that posts ``{"user": "someone@example.com"}`` gets nothing.

Google is implemented. Apple is the same shape - a different issuer, a different
JWKS URL - so the verifier is written provider-agnostically and Apple slots in
without restructuring.
"""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

import httpx
import jwt
from jwt import PyJWKClient

from ..config import settings
from ..errors import ErrorCode, Unauthorized
from ..security import now

log = logging.getLogger(__name__)

GOOGLE_ISSUERS = frozenset({"accounts.google.com", "https://accounts.google.com"})
GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"


@dataclass(frozen=True)
class FederatedClaims:
    """The only things we take from a provider token."""

    provider: str
    subject: str
    email: str | None
    email_verified: bool
    display_name: str | None
    picture: str | None


class _JwksCache:
    """Caches provider signing keys.

    Providers rotate keys, so an unknown ``kid`` must trigger a refetch rather
    than a rejection - otherwise every rotation causes an outage. PyJWKClient
    handles that plus caching; this wrapper exists so the client is created once
    per URL rather than per request.
    """

    def __init__(self) -> None:
        self._clients: dict[str, PyJWKClient] = {}

    def client(self, jwks_url: str) -> PyJWKClient:
        if jwks_url not in self._clients:
            self._clients[jwks_url] = PyJWKClient(
                jwks_url,
                cache_keys=True,
                lifespan=int(timedelta(hours=12).total_seconds()),
            )
        return self._clients[jwks_url]

    def reset(self) -> None:
        """For tests, and for forcing a refetch after a suspected rotation."""
        self._clients.clear()


_jwks = _JwksCache()


def reset_jwks_cache() -> None:
    _jwks.reset()


def _signing_key(jwks_url: str, token: str) -> Any:
    try:
        return _jwks.client(jwks_url).get_signing_key_from_jwt(token).key
    except (jwt.PyJWKClientError, httpx.HTTPError, OSError) as exc:
        # A provider outage or a network failure is not the user's fault, and it
        # is not "invalid credentials" either. Say so distinctly.
        log.warning("JWKS unavailable at %s: %s", jwks_url, type(exc).__name__)
        raise Unauthorized(
            "Could not reach the sign-in provider. Try again.",
            code=ErrorCode.AUTH_PROVIDER_UNAVAILABLE,
        ) from exc


def _decode(
    token: str,
    *,
    jwks_url: str,
    audiences: list[str],
    issuers: frozenset[str] | set[str],
    provider: str,
) -> dict[str, Any]:
    if not audiences:
        raise Unauthorized(
            f"{provider} sign-in is not configured on this server.",
            code=ErrorCode.AUTH_PROVIDER_NOT_CONFIGURED,
        )

    key = _signing_key(jwks_url, token)
    try:
        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            # Any of our configured client ids is acceptable: Android, iOS and
            # web each have their own, and all three are us.
            audience=audiences,
            options={"require": ["exp", "iat", "sub", "aud", "iss"]},
            leeway=30,
        )
    except jwt.ExpiredSignatureError as exc:
        raise Unauthorized(
            "That sign-in attempt expired. Try again.",
            code=ErrorCode.AUTH_TOKEN_EXPIRED,
        ) from exc
    except jwt.InvalidAudienceError as exc:
        # The token is genuine but was minted for a different app. This is the
        # signature of a replayed token from another product.
        raise Unauthorized(
            "This sign-in token was not issued for this app.",
            code=ErrorCode.AUTH_TOKEN_INVALID,
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise Unauthorized(
            "Sign-in token is not valid.", code=ErrorCode.AUTH_TOKEN_INVALID
        ) from exc

    if payload.get("iss") not in issuers:
        raise Unauthorized(
            "Sign-in token has an unexpected issuer.",
            code=ErrorCode.AUTH_TOKEN_INVALID,
        )

    return payload


def _check_nonce(payload: dict[str, Any], expected_raw_nonce: str | None) -> None:
    """Bind the token to this sign-in attempt.

    Without a nonce, a token captured from one session can be replayed into
    another. `google_sign_in` sends the SHA-256 of the raw nonce, so compare
    hashes, not the raw value.
    """
    if expected_raw_nonce is None:
        return

    claimed = payload.get("nonce")
    if not claimed:
        raise Unauthorized(
            "Sign-in token is missing its nonce.", code=ErrorCode.AUTH_TOKEN_INVALID
        )

    digest = hashlib.sha256(expected_raw_nonce.encode("utf-8")).hexdigest()
    if claimed not in (expected_raw_nonce, digest):
        raise Unauthorized(
            "Sign-in token does not match this attempt.",
            code=ErrorCode.AUTH_TOKEN_INVALID,
        )


def verify_google_id_token(
    id_token: str, *, raw_nonce: str | None = None
) -> FederatedClaims:
    payload = _decode(
        id_token,
        jwks_url=GOOGLE_JWKS_URL,
        audiences=settings.google_audience_list,
        issuers=GOOGLE_ISSUERS,
        provider="Google",
    )
    _check_nonce(payload, raw_nonce)

    email = payload.get("email")
    # Google sends this as a real bool or the string "true" depending on the
    # endpoint that minted the token.
    verified_raw = payload.get("email_verified", False)
    verified = verified_raw is True or str(verified_raw).lower() == "true"

    return FederatedClaims(
        provider="google",
        subject=str(payload["sub"]),
        email=email.strip().lower() if isinstance(email, str) else None,
        email_verified=bool(email) and verified,
        display_name=payload.get("name") or None,
        picture=payload.get("picture") or None,
    )


def verify_apple_id_token(
    id_token: str, *, raw_nonce: str | None = None
) -> FederatedClaims:
    """Apple, for when the iOS build happens.

    Note the two Apple-specific traps: `email` is absent on every sign-in after
    the first, and with "Hide My Email" it is a relay address. `sub` is the only
    stable identity, which is why linking keys on it and never on the address.
    """
    payload = _decode(
        id_token,
        jwks_url=APPLE_JWKS_URL,
        audiences=settings.apple_audience_list,
        issuers={APPLE_ISSUER},
        provider="Apple",
    )
    _check_nonce(payload, raw_nonce)

    email = payload.get("email")
    verified_raw = payload.get("email_verified", False)
    verified = verified_raw is True or str(verified_raw).lower() == "true"

    return FederatedClaims(
        provider="apple",
        subject=str(payload["sub"]),
        email=email.strip().lower() if isinstance(email, str) else None,
        email_verified=bool(email) and verified,
        display_name=None,  # Apple never puts a name in the token.
        picture=None,
    )


def issued_recently(payload: dict[str, Any], *, max_age_seconds: int = 600) -> bool:
    """Provider tokens are short-lived; anything old is a replay."""
    iat = payload.get("iat")
    if not iat:
        return False
    return (now().timestamp() - float(iat)) <= max_age_seconds
