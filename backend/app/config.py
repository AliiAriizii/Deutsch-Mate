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
    public_base_url: str = "http://127.0.0.1:8000"
    cors_origins: str = "http://localhost:*,http://127.0.0.1:*"
    email_verification_required: bool = True
    # Guards content publishing. Empty is tolerated outside prod so local
    # authoring needs no key.
    admin_api_key: str = ""

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
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
