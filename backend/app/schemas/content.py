"""Content manifest and package bodies."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from ..models.enums import CefrLevel


class ManifestEntry(BaseModel):
    level_id: CefrLevel
    version: str
    schema_version: int
    checksum: str
    min_app_version: str
    lektion_count: int
    exercise_count: int
    published_at: datetime | None


class ManifestOut(BaseModel):
    """What the client polls on launch. It compares each entry's version against
    the bundled/cached copy and pulls only what changed."""

    entries: list[ManifestEntry]
    server_time: datetime


class PackageOut(BaseModel):
    level_id: CefrLevel
    version: str
    schema_version: int
    checksum: str
    min_app_version: str
    payload: dict[str, Any]


class PublishPackageRequest(BaseModel):
    level_id: CefrLevel
    version: str = Field(min_length=1, max_length=32)
    schema_version: int = 1
    min_app_version: str = "1.0.0"
    payload: dict[str, Any]
    notes: str | None = Field(default=None, max_length=500)
    publish: bool = True
