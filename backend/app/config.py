"""Application settings, loaded from environment / .env."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Mongo ---
    mongodb_url: str = "mongodb://127.0.0.1:27017"
    mongodb_db: str = "deutschmate"

    # --- JWT ---
    jwt_secret: str = "CHANGE_ME_dev_only_secret_do_not_ship"
    jwt_algorithm: str = "HS256"
    access_token_ttl_minutes: int = 30
    refresh_token_ttl_days: int = 60

    # --- Mail ---
    mail_backend: Literal["console", "smtp"] = "console"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_use_tls: bool = True
    mail_from: str = "no-reply@deutschmate.local"

    # --- App ---
    app_env: Literal["dev", "test", "prod"] = "dev"
    # Vercel sets VERCEL=1 in every function environment. Empty everywhere
    # else, which is how the app tells a long-lived process from a function
    # instance without a second knob to keep in sync.
    vercel: str = ""
    public_base_url: str = "http://127.0.0.1:8000"
    cors_origins: str = "http://localhost:*,http://127.0.0.1:*"
    email_verification_required: bool = True
    # Guards content publishing. Empty is tolerated outside prod so local
    # authoring needs no key.
    admin_api_key: str = ""

    # --- Federated sign-in ---
    # Comma-separated OAuth client ids that may appear as the `aud` of an ID
    # token. Android, iOS and web each get their own from Google, and all of
    # them are legitimately us. Empty means the provider is switched off.
    google_client_ids: str = ""
    apple_client_ids: str = ""

    # --- Auth hardening ---
    max_failed_logins: int = 10
    lockout_minutes: int = 15
    email_token_ttl_hours: int = 24
    reset_token_ttl_minutes: int = 60

    # --- Password policy (single source of truth; also served to the client) ---
    password_min_length: int = 10
    password_max_length: int = 128
    password_require_letter: bool = True
    password_require_digit: bool = True

    @field_validator("jwt_secret")
    @classmethod
    def _reject_default_secret_in_prod(cls, v: str, info) -> str:
        if info.data.get("app_env") == "prod" and "CHANGE_ME" in v:
            raise ValueError("JWT_SECRET must be set to a real value when APP_ENV=prod")
        return v

    @property
    def is_serverless(self) -> bool:
        return bool(self.vercel)

    @property
    def mongo_max_pool_size(self) -> int:
        """Connections per instance.

        Atlas caps total connections per cluster (500 on M0), and a serverless
        deployment multiplies whatever this is by the number of live instances.
        Fluid Compute serves several concurrent requests per instance, so 1
        would serialise every database call; a small pool is the middle ground.
        """
        return 5 if self.is_serverless else 100

    @property
    def google_audience_list(self) -> list[str]:
        return [c.strip() for c in self.google_client_ids.split(",") if c.strip()]

    @property
    def apple_audience_list(self) -> list[str]:
        return [c.strip() for c in self.apple_client_ids.split(",") if c.strip()]

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
