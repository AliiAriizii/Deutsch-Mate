"""Typed application errors.

Every failure the client can encounter has a stable machine code. The Flutter
client maps `code` -> localised human message; it never renders `message`
directly except as a last-resort fallback in dev.
"""

from enum import StrEnum
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ErrorCode(StrEnum):
    # --- auth: signup ---
    AUTH_EMAIL_TAKEN = "AUTH_EMAIL_TAKEN"
    AUTH_WEAK_PASSWORD = "AUTH_WEAK_PASSWORD"

    # --- auth: signin ---
    AUTH_INVALID_CREDENTIALS = "AUTH_INVALID_CREDENTIALS"
    AUTH_EMAIL_NOT_VERIFIED = "AUTH_EMAIL_NOT_VERIFIED"
    AUTH_ACCOUNT_LOCKED = "AUTH_ACCOUNT_LOCKED"
    AUTH_ACCOUNT_DISABLED = "AUTH_ACCOUNT_DISABLED"

    # --- auth: tokens ---
    AUTH_TOKEN_MISSING = "AUTH_TOKEN_MISSING"
    AUTH_TOKEN_INVALID = "AUTH_TOKEN_INVALID"
    AUTH_TOKEN_EXPIRED = "AUTH_TOKEN_EXPIRED"
    AUTH_REFRESH_INVALID = "AUTH_REFRESH_INVALID"
    AUTH_REFRESH_EXPIRED = "AUTH_REFRESH_EXPIRED"
    AUTH_REFRESH_REVOKED = "AUTH_REFRESH_REVOKED"

    # --- auth: federated sign-in ---
    AUTH_PROVIDER_NOT_CONFIGURED = "AUTH_PROVIDER_NOT_CONFIGURED"
    AUTH_PROVIDER_UNAVAILABLE = "AUTH_PROVIDER_UNAVAILABLE"
    # The email already has a password account. Linking requires proving
    # ownership of it, or an attacker who controls a matching Google address
    # could take over the account.
    AUTH_LINK_REQUIRES_PASSWORD = "AUTH_LINK_REQUIRES_PASSWORD"
    AUTH_PROVIDER_EMAIL_UNVERIFIED = "AUTH_PROVIDER_EMAIL_UNVERIFIED"
    # The account exists but has no password - it was created through a
    # provider. Telling the user which one leaks nothing that signup's
    # AUTH_EMAIL_TAKEN does not already reveal, and without it they would face
    # a permanently "wrong" password.
    AUTH_USE_PROVIDER_SIGNIN = "AUTH_USE_PROVIDER_SIGNIN"

    # --- auth: one-time tokens ---
    AUTH_VERIFY_TOKEN_INVALID = "AUTH_VERIFY_TOKEN_INVALID"
    AUTH_VERIFY_TOKEN_EXPIRED = "AUTH_VERIFY_TOKEN_EXPIRED"
    AUTH_ALREADY_VERIFIED = "AUTH_ALREADY_VERIFIED"
    AUTH_RESET_TOKEN_INVALID = "AUTH_RESET_TOKEN_INVALID"
    AUTH_RESET_TOKEN_EXPIRED = "AUTH_RESET_TOKEN_EXPIRED"

    # --- generic ---
    RATE_LIMITED = "RATE_LIMITED"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    NOT_FOUND = "NOT_FOUND"
    CONFLICT = "CONFLICT"
    FORBIDDEN = "FORBIDDEN"
    INTERNAL = "INTERNAL"

    # --- content ---
    CONTENT_VERSION_UNKNOWN = "CONTENT_VERSION_UNKNOWN"
    CONTENT_CHECKSUM_MISMATCH = "CONTENT_CHECKSUM_MISMATCH"

    # --- progress ---
    PROGRESS_LEKTION_LOCKED = "PROGRESS_LEKTION_LOCKED"


class AppError(Exception):
    """Base for every error the API deliberately returns."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: ErrorCode = ErrorCode.INTERNAL

    def __init__(
        self,
        message: str | None = None,
        *,
        code: ErrorCode | None = None,
        status_code: int | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        if code is not None:
            self.code = code
        if status_code is not None:
            self.status_code = status_code
        self.message = message or self.code.value
        self.details = details or {}
        super().__init__(self.message)

    def to_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"code": self.code.value, "message": self.message}
        if self.details:
            payload["details"] = self.details
        return {"error": payload}


class BadRequest(AppError):
    status_code = status.HTTP_400_BAD_REQUEST
    code = ErrorCode.VALIDATION_ERROR


class Unauthorized(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = ErrorCode.AUTH_TOKEN_INVALID


class Forbidden(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    code = ErrorCode.FORBIDDEN


class NotFound(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = ErrorCode.NOT_FOUND


class Conflict(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = ErrorCode.CONFLICT


class RateLimited(AppError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    code = ErrorCode.RATE_LIMITED


# Starlette renamed the 422 constant. Probe with hasattr rather than a getattr
# default, which would touch the deprecated name and emit its warning.
HTTP_422 = (
    status.HTTP_422_UNPROCESSABLE_CONTENT
    if hasattr(status, "HTTP_422_UNPROCESSABLE_CONTENT")
    else status.HTTP_422_UNPROCESSABLE_ENTITY
)


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        headers = {}
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            headers["WWW-Authenticate"] = "Bearer"
        return JSONResponse(
            content=exc.to_payload(), status_code=exc.status_code, headers=headers
        )

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        # Collapse pydantic's shape into field -> message so the client can bind
        # each message to the right input without parsing loc arrays.
        fields: dict[str, str] = {}
        for err in exc.errors():
            loc = [
                str(p)
                for p in err.get("loc", [])
                if p not in ("body", "query", "path")
            ]
            fields[".".join(loc) or "_"] = err.get("msg", "invalid")
        return JSONResponse(
            content={
                "error": {
                    "code": ErrorCode.VALIDATION_ERROR.value,
                    "message": "One or more fields are invalid.",
                    "details": {"fields": fields},
                }
            },
            status_code=HTTP_422,
        )
