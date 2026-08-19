"""Outbound mail.

``MAIL_BACKEND=console`` prints the message (including the verification link) to
stdout - the dev default, so the whole flow is exercisable without an SMTP
account. ``MAIL_BACKEND=smtp`` actually sends. Nothing is faked: a failed send
raises, it does not silently succeed.
"""

from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

import anyio

from .config import settings

log = logging.getLogger(__name__)


def _render(subject: str, to: str, body: str) -> EmailMessage:
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = settings.mail_from
    msg["To"] = to
    msg.set_content(body)
    return msg


def _send_smtp_blocking(msg: EmailMessage) -> None:
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        if settings.smtp_user:
            smtp.login(settings.smtp_user, settings.smtp_password)
        smtp.send_message(msg)


async def send_mail(*, to: str, subject: str, body: str) -> None:
    msg = _render(subject, to, body)

    if settings.mail_backend == "console":
        print(
            "\n"
            "--- MAIL (console backend) -------------------------------------\n"
            f"To:      {to}\n"
            f"Subject: {subject}\n"
            "----------------------------------------------------------------\n"
            f"{body}"
            "----------------------------------------------------------------\n",
            flush=True,
        )
        return

    if not settings.smtp_host:
        raise RuntimeError("MAIL_BACKEND=smtp but SMTP_HOST is empty.")
    await anyio.to_thread.run_sync(_send_smtp_blocking, msg)
    log.info("mail sent to %s: %s", to, subject)


async def send_verification_email(*, to: str, display_name: str, token: str) -> None:
    link = f"{settings.public_base_url}/api/v1/auth/verify-email?token={token}"
    await send_mail(
        to=to,
        subject="Confirm your DeutschMate email",
        body=(
            f"Hallo {display_name},\n\n"
            "Confirm this address to activate your DeutschMate account:\n\n"
            f"{link}\n\n"
            f"The link is valid for {settings.email_token_ttl_hours} hours.\n"
            "If you did not create the account, ignore this message.\n"
        ),
    )


async def send_password_reset_email(*, to: str, display_name: str, code: str) -> None:
    await send_mail(
        to=to,
        subject="Reset your DeutschMate password",
        body=(
            f"Hallo {display_name},\n\n"
            "Enter this code in the app to set a new password:\n\n"
            f"    {code}\n\n"
            f"The code is valid for {settings.reset_token_ttl_minutes} minutes.\n"
            "If you did not request a reset, ignore this message - your "
            "password stays unchanged.\n"
        ),
    )
