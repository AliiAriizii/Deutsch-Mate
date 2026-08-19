"""Authentication and account lifecycle.

Shape of the flow the client implements against this:

    cold start -> refresh (silent)             -> home | auth
    sign up    -> verify email -> onboarding   -> home
    sign in    -> [verify email] -> onboarding -> home

Every failure carries a stable ``error.code`` so the client can map it to a
localised message; no raw exception text ever reaches a user.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Query, Request, Response, status
from pymongo.errors import DuplicateKeyError

from ..config import settings
from ..deps import CurrentUser
from ..errors import (
    BadRequest,
    Conflict,
    ErrorCode,
    NotFound,
    RateLimited,
    Unauthorized,
)
from ..mail import send_password_reset_email, send_verification_email
from ..models.enums import TokenPurpose, UserStatus
from ..models.progress import ExerciseAttempt, LektionProgress, UserStats
from ..models.session import RefreshSession
from ..models.token import OneTimeToken
from ..models.user import OnboardingProfile, User
from ..schemas.auth import (
    AuthResult,
    ChangePasswordRequest,
    DeleteAccountRequest,
    ForgotPasswordRequest,
    LogoutRequest,
    MessageOut,
    OnboardingOut,
    OnboardingRequest,
    PasswordPolicyOut,
    RefreshRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    SignInRequest,
    SignUpRequest,
    TokenPair,
    UserOut,
    VerifyEmailRequest,
)
from ..security import (
    create_access_token,
    generate_numeric_code,
    generate_opaque_token,
    hash_password,
    needs_rehash,
    now,
    password_policy,
    token_fingerprint,
    validate_password,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])

MAX_RESET_ATTEMPTS = 5


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #


def _user_out(user: User) -> UserOut:
    return UserOut(
        id=str(user.id),
        email=user.email,
        display_name=user.display_name,
        phone=user.phone,
        email_verified=user.email_verified,
        status=user.status.value,
        onboarding=OnboardingOut(
            target_level=user.onboarding.target_level,
            daily_goal_minutes=user.onboarding.daily_goal_minutes,
            interface_language=user.onboarding.interface_language,
            completed=user.onboarding.completed,
        ),
        placement_level=user.placement_level,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


async def _issue_tokens(
    user: User,
    *,
    request: Request,
    device_id: str | None = None,
) -> TokenPair:
    access, expires_at = create_access_token(
        str(user.id), email_verified=user.email_verified
    )
    refresh = generate_opaque_token()
    session = RefreshSession(
        user_id=user.id,
        token_fingerprint=token_fingerprint(refresh),
        expires_at=now() + timedelta(days=settings.refresh_token_ttl_days),
        device_id=device_id,
        user_agent=request.headers.get("user-agent"),
    )
    await session.insert()
    return TokenPair(
        access_token=access,
        refresh_token=refresh,
        expires_at=expires_at,
        expires_in=settings.access_token_ttl_minutes * 60,
    )


async def _new_verification_token(user: User) -> str:
    raw = generate_opaque_token()
    await OneTimeToken(
        user_id=user.id,
        purpose=TokenPurpose.EMAIL_VERIFY,
        token_fingerprint=token_fingerprint(raw),
        expires_at=now() + timedelta(hours=settings.email_token_ttl_hours),
    ).insert()
    return raw


def _assert_password_ok(password: str) -> None:
    violations = validate_password(password)
    if violations:
        raise BadRequest(
            "Password does not meet the policy.",
            code=ErrorCode.AUTH_WEAK_PASSWORD,
            details={"violations": violations, "policy": password_policy()},
        )


async def _revoke_all_sessions(user: User, reason: str) -> int:
    sessions = await RefreshSession.find(
        RefreshSession.user_id == user.id,
        RefreshSession.revoked_at == None,  # noqa: E711 - Beanie query operator
    ).to_list()
    for s in sessions:
        s.revoke(reason)
        await s.save()
    return len(sessions)


# --------------------------------------------------------------------------- #
# policy
# --------------------------------------------------------------------------- #


@router.get("/password-policy", response_model=PasswordPolicyOut)
async def get_password_policy() -> PasswordPolicyOut:
    """The client renders the rules from here *before* the user types, so the
    stated rules and the enforced rules cannot drift apart."""
    return PasswordPolicyOut(**password_policy())


# --------------------------------------------------------------------------- #
# sign up / verify
# --------------------------------------------------------------------------- #


@router.post("/signup", response_model=AuthResult, status_code=status.HTTP_201_CREATED)
async def sign_up(body: SignUpRequest, request: Request) -> AuthResult:
    _assert_password_ok(body.password)

    email_key = User.normalize_email(body.email)
    user = User(
        email=body.email.strip(),
        email_key=email_key,
        password_hash=hash_password(body.password),
        display_name=body.display_name,
        phone=body.phone,
    )
    try:
        await user.insert()
    except DuplicateKeyError as exc:
        # The unique index - not a pre-check - is what makes a double-tapped
        # sign-up impossible to duplicate.
        raise Conflict(
            "An account already exists for this email address.",
            code=ErrorCode.AUTH_EMAIL_TAKEN,
        ) from exc

    await UserStats(user_id=user.id).insert()

    raw_token = await _new_verification_token(user)
    await send_verification_email(
        to=user.email, display_name=user.display_name, token=raw_token
    )

    if settings.email_verification_required:
        # No tokens yet: the client routes to the verify screen and has nothing
        # to persist, so there is no half-authenticated state to leak.
        return AuthResult(user=_user_out(user), email_verification_required=True)

    tokens = await _issue_tokens(user, request=request)
    return AuthResult(user=_user_out(user), tokens=tokens)


@router.post("/verify-email", response_model=AuthResult)
async def verify_email(body: VerifyEmailRequest, request: Request) -> AuthResult:
    return await _consume_verification(body.token, request)


@router.get("/verify-email", response_model=AuthResult)
async def verify_email_via_link(
    request: Request,
    token: Annotated[str, Query(min_length=1, max_length=256)],
) -> AuthResult:
    """Same operation as the POST, reachable from the emailed link."""
    return await _consume_verification(token, request)


async def _consume_verification(raw_token: str, request: Request) -> AuthResult:
    record = await OneTimeToken.find_one(
        OneTimeToken.token_fingerprint == token_fingerprint(raw_token),
        OneTimeToken.purpose == TokenPurpose.EMAIL_VERIFY,
    )
    if record is None:
        raise BadRequest(
            "This confirmation link is not valid.",
            code=ErrorCode.AUTH_VERIFY_TOKEN_INVALID,
        )
    if record.used_at is not None:
        raise BadRequest(
            "This confirmation link was already used.",
            code=ErrorCode.AUTH_VERIFY_TOKEN_INVALID,
        )
    if record.expires_at <= now():
        raise BadRequest(
            "This confirmation link has expired.",
            code=ErrorCode.AUTH_VERIFY_TOKEN_EXPIRED,
        )

    user = await User.get(record.user_id)
    if user is None:
        raise NotFound("The account for this link no longer exists.")

    record.used_at = now()
    await record.save()

    if not user.email_verified:
        user.email_verified = True
        user.email_verified_at = now()
        user.touch()
        await user.save()

    tokens = await _issue_tokens(user, request=request)
    return AuthResult(user=_user_out(user), tokens=tokens)


@router.post("/resend-verification", response_model=MessageOut)
async def resend_verification(body: ResendVerificationRequest) -> MessageOut:
    """Always reports success. A different answer for known vs unknown
    addresses would turn this into an account-enumeration oracle."""
    generic = MessageOut(message="If that address needs confirming, a new link is on its way.")

    user = await User.find_one(User.email_key == User.normalize_email(body.email))
    if user is None or user.email_verified:
        return generic

    raw_token = await _new_verification_token(user)
    await send_verification_email(
        to=user.email, display_name=user.display_name, token=raw_token
    )
    return generic


# --------------------------------------------------------------------------- #
# sign in / refresh / sign out
# --------------------------------------------------------------------------- #


@router.post("/signin", response_model=AuthResult)
async def sign_in(body: SignInRequest, request: Request) -> AuthResult:
    invalid = Unauthorized(
        "Email address or password is incorrect.",
        code=ErrorCode.AUTH_INVALID_CREDENTIALS,
    )

    user = await User.find_one(User.email_key == User.normalize_email(body.email))
    if user is None:
        raise invalid

    if user.is_locked:
        remaining = int((user.locked_until - now()).total_seconds())
        raise RateLimited(
            "Too many failed attempts. Try again shortly.",
            code=ErrorCode.AUTH_ACCOUNT_LOCKED,
            details={"retry_after_seconds": max(remaining, 1)},
        )

    if user.status is not UserStatus.ACTIVE:
        raise Unauthorized(
            "This account is disabled.", code=ErrorCode.AUTH_ACCOUNT_DISABLED
        )

    if not verify_password(body.password, user.password_hash):
        user.failed_login_count += 1
        if user.failed_login_count >= settings.max_failed_logins:
            user.locked_until = now() + timedelta(minutes=settings.lockout_minutes)
            user.failed_login_count = 0
        user.touch()
        await user.save()
        raise invalid

    # Argon2 parameters can change between releases; re-hash on the next
    # successful sign-in rather than leaving old hashes in place forever.
    if needs_rehash(user.password_hash):
        user.password_hash = hash_password(body.password)

    user.failed_login_count = 0
    user.locked_until = None
    user.last_login_at = now()
    user.touch()
    await user.save()

    if settings.email_verification_required and not user.email_verified:
        raise Unauthorized(
            "Confirm your email address before signing in.",
            code=ErrorCode.AUTH_EMAIL_NOT_VERIFIED,
            details={"email": user.email},
        )

    tokens = await _issue_tokens(user, request=request, device_id=body.device_id)
    return AuthResult(user=_user_out(user), tokens=tokens)


@router.post("/refresh", response_model=TokenPair)
async def refresh_tokens(body: RefreshRequest, request: Request) -> TokenPair:
    """Rotating refresh. Called on cold start before the first frame, so the app
    can route straight to home or auth without showing the wrong one first."""
    fingerprint = token_fingerprint(body.refresh_token)
    session = await RefreshSession.find_one(
        RefreshSession.token_fingerprint == fingerprint
    )
    if session is None:
        raise Unauthorized(
            "This session is not valid.", code=ErrorCode.AUTH_REFRESH_INVALID
        )

    if session.revoked_at is not None:
        # A revoked token being presented means it leaked (or the client is
        # replaying). Kill every session for that user.
        user = await User.get(session.user_id)
        if user is not None:
            await _revoke_all_sessions(user, "refresh_replay_detected")
        raise Unauthorized(
            "This session was revoked. Sign in again.",
            code=ErrorCode.AUTH_REFRESH_REVOKED,
        )

    if session.expires_at <= now():
        raise Unauthorized(
            "This session has expired. Sign in again.",
            code=ErrorCode.AUTH_REFRESH_EXPIRED,
        )

    user = await User.get(session.user_id)
    if user is None or user.status is not UserStatus.ACTIVE:
        raise Unauthorized(
            "This account is no longer active.",
            code=ErrorCode.AUTH_ACCOUNT_DISABLED,
        )

    new_tokens = await _issue_tokens(
        user, request=request, device_id=session.device_id
    )
    successor = await RefreshSession.find_one(
        RefreshSession.token_fingerprint == token_fingerprint(new_tokens.refresh_token)
    )

    session.revoke("rotated")
    session.last_used_at = now()
    if successor is not None:
        session.replaced_by = successor.id
    await session.save()

    return new_tokens


@router.post("/logout", response_model=MessageOut)
async def logout(body: LogoutRequest, user: CurrentUser) -> MessageOut:
    if body.all_devices:
        count = await _revoke_all_sessions(user, "logout_all")
        return MessageOut(message=f"Signed out of {count} session(s).")

    if body.refresh_token:
        session = await RefreshSession.find_one(
            RefreshSession.token_fingerprint == token_fingerprint(body.refresh_token),
            RefreshSession.user_id == user.id,
        )
        if session is not None and session.revoked_at is None:
            session.revoke("logout")
            await session.save()
    return MessageOut(message="Signed out.")


# --------------------------------------------------------------------------- #
# password reset / change
# --------------------------------------------------------------------------- #


@router.post("/forgot-password", response_model=MessageOut)
async def forgot_password(body: ForgotPasswordRequest) -> MessageOut:
    generic = MessageOut(message="If that address has an account, a reset code is on its way.")

    user = await User.find_one(User.email_key == User.normalize_email(body.email))
    if user is None or user.status is not UserStatus.ACTIVE:
        return generic

    # Invalidate any outstanding codes so only the newest one works.
    outstanding = await OneTimeToken.find(
        OneTimeToken.user_id == user.id,
        OneTimeToken.purpose == TokenPurpose.PASSWORD_RESET,
        OneTimeToken.used_at == None,  # noqa: E711 - Beanie query operator
    ).to_list()
    for token in outstanding:
        token.used_at = now()
        await token.save()

    code = generate_numeric_code()
    await OneTimeToken(
        user_id=user.id,
        purpose=TokenPurpose.PASSWORD_RESET,
        token_fingerprint=token_fingerprint(code + str(user.id)),
        expires_at=now() + timedelta(minutes=settings.reset_token_ttl_minutes),
    ).insert()

    await send_password_reset_email(
        to=user.email, display_name=user.display_name, code=code
    )
    return generic


@router.post("/reset-password", response_model=MessageOut)
async def reset_password(body: ResetPasswordRequest) -> MessageOut:
    _assert_password_ok(body.new_password)

    user = await User.find_one(User.email_key == User.normalize_email(body.email))
    invalid = BadRequest(
        "This reset code is not valid.", code=ErrorCode.AUTH_RESET_TOKEN_INVALID
    )
    if user is None:
        raise invalid

    # The code is salted with the user id, so a code issued for one account can
    # never be redeemed against another.
    record = await OneTimeToken.find_one(
        OneTimeToken.token_fingerprint == token_fingerprint(body.code + str(user.id)),
        OneTimeToken.purpose == TokenPurpose.PASSWORD_RESET,
    )
    if record is None or record.user_id != user.id:
        raise invalid
    if record.used_at is not None:
        raise invalid
    if record.expires_at <= now():
        raise BadRequest(
            "This reset code has expired.", code=ErrorCode.AUTH_RESET_TOKEN_EXPIRED
        )
    if record.attempt_count >= MAX_RESET_ATTEMPTS:
        raise RateLimited(
            "Too many attempts with this code. Request a new one.",
            code=ErrorCode.RATE_LIMITED,
        )

    record.attempt_count += 1
    record.used_at = now()
    await record.save()

    user.password_hash = hash_password(body.new_password)
    user.failed_login_count = 0
    user.locked_until = None
    user.touch()
    await user.save()

    # A password change ends every existing session, on every device.
    await _revoke_all_sessions(user, "password_reset")
    return MessageOut(message="Password updated. Sign in with the new password.")


@router.post("/change-password", response_model=MessageOut)
async def change_password(body: ChangePasswordRequest, user: CurrentUser) -> MessageOut:
    if not verify_password(body.current_password, user.password_hash):
        raise Unauthorized(
            "Current password is incorrect.", code=ErrorCode.AUTH_INVALID_CREDENTIALS
        )
    _assert_password_ok(body.new_password)

    user.password_hash = hash_password(body.new_password)
    user.touch()
    await user.save()
    await _revoke_all_sessions(user, "password_change")
    return MessageOut(message="Password updated. Other devices were signed out.")


# --------------------------------------------------------------------------- #
# profile / onboarding / deletion
# --------------------------------------------------------------------------- #


@router.get("/me", response_model=UserOut)
async def read_me(user: CurrentUser) -> UserOut:
    return _user_out(user)


@router.post("/onboarding", response_model=UserOut)
async def complete_onboarding(body: OnboardingRequest, user: CurrentUser) -> UserOut:
    """Target level, daily goal, interface language. The target level also seeds
    the start position in the content tree when no placement test was taken."""
    user.onboarding = OnboardingProfile(
        target_level=body.target_level,
        daily_goal_minutes=body.daily_goal_minutes,
        interface_language=body.interface_language,
        completed=True,
        completed_at=now(),
    )
    if user.placement_level is None:
        user.placement_level = body.target_level
        user.placement_source = "default"
    user.touch()
    await user.save()
    return _user_out(user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(body: DeleteAccountRequest, user: CurrentUser) -> Response:
    """Hard delete, required by both app stores.

    Re-auth is mandatory, so a stolen access token alone cannot destroy an
    account. Everything keyed to the user goes with it.
    """
    if not body.confirm:
        raise BadRequest(
            "Deletion must be confirmed.",
            details={"fields": {"confirm": "must be true"}},
        )
    if not verify_password(body.password, user.password_hash):
        raise Unauthorized(
            "Password is incorrect.", code=ErrorCode.AUTH_INVALID_CREDENTIALS
        )

    user_id = user.id
    await RefreshSession.find(RefreshSession.user_id == user_id).delete()
    await OneTimeToken.find(OneTimeToken.user_id == user_id).delete()
    await LektionProgress.find(LektionProgress.user_id == user_id).delete()
    await ExerciseAttempt.find(ExerciseAttempt.user_id == user_id).delete()
    await UserStats.find(UserStats.user_id == user_id).delete()
    await user.delete()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
