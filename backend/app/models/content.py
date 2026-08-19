"""Published content packages - one per level, versioned.

This is what makes lessons updatable without an app-store release: the client
ships a bundled copy of each package for offline-first cold start, then asks
``/content/manifest`` whether a newer version exists and pulls it into its local
DB. The payload is the level JSON that the shared schema validates.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from beanie import Document
from pydantic import Field
from pymongo import ASCENDING, DESCENDING, IndexModel

from ..security import now
from .enums import CefrLevel


class ContentPackage(Document):
    level_id: CefrLevel
    # Semver of the content, not of the app.
    version: str
    schema_version: int = 1
    # SHA-256 of the canonical JSON payload. The client verifies after download.
    checksum: str
    payload: dict[str, Any]

    # Guards against shipping content that needs a renderer the installed app
    # does not have yet.
    min_app_version: str = "1.0.0"
    is_published: bool = False
    published_at: datetime | None = None

    lektion_count: int = 0
    exercise_count: int = 0
    notes: str | None = None

    created_at: datetime = Field(default_factory=now)

    class Settings:
        name = "content_packages"
        indexes = [
            IndexModel(
                [("level_id", ASCENDING), ("version", ASCENDING)],
                unique=True,
                name="uq_content_level_version",
            ),
            IndexModel(
                [("level_id", ASCENDING), ("is_published", ASCENDING), ("published_at", DESCENDING)],
                name="ix_content_published",
            ),
        ]
