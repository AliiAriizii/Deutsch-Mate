"""Content delivery: manifest, package download, publish.

The client ships every level bundled for a cold offline start, then compares the
manifest on launch and pulls only what changed. That is what lets a Lektion be
corrected without an app-store release.
"""

from __future__ import annotations

import hashlib
import json
from typing import Annotated, Any

from fastapi import APIRouter, Header, Query, status

from ..config import settings
from ..errors import ErrorCode, Forbidden, NotFound
from ..models.content import ContentPackage
from ..models.enums import CefrLevel
from ..schemas.content import (
    ManifestEntry,
    ManifestOut,
    PackageOut,
    PublishPackageRequest,
)
from ..security import now

router = APIRouter(prefix="/content", tags=["content"])


def canonical_checksum(payload: dict[str, Any]) -> str:
    """SHA-256 over canonical JSON (sorted keys, tight separators) so the same
    logical content always produces the same digest on both sides."""
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _count_nodes(payload: dict[str, Any]) -> tuple[int, int]:
    """(lektion_count, exercise_count) for the manifest, tolerant of a payload
    that has not been schema-validated yet."""
    lektionen = 0
    exercises = 0
    for modul in payload.get("module", []) or []:
        for lektion in modul.get("lektionen", []) or []:
            lektionen += 1
            for section in lektion.get("sections", []) or []:
                exercises += len(section.get("exercises", []) or [])
    return lektionen, exercises


async def _require_admin(token: str | None) -> None:
    if not settings.admin_api_key:
        # No key configured: publishing is a local-dev affordance only.
        if settings.app_env == "prod":
            raise Forbidden("Publishing is disabled: ADMIN_API_KEY is not set.")
        return
    if token != settings.admin_api_key:
        raise Forbidden("Admin key is missing or wrong.")


@router.get("/manifest", response_model=ManifestOut)
async def get_manifest() -> ManifestOut:
    """Latest published version per level. Unauthenticated on purpose: content
    is not user data, and the app needs it before sign-in."""
    entries: list[ManifestEntry] = []
    for level in CefrLevel:
        pkg = (
            await ContentPackage.find(
                ContentPackage.level_id == level,
                ContentPackage.is_published == True,  # noqa: E712 - Beanie operator
            )
            .sort("-published_at")
            .first_or_none()
        )
        if pkg is None:
            continue
        entries.append(
            ManifestEntry(
                level_id=pkg.level_id,
                version=pkg.version,
                schema_version=pkg.schema_version,
                checksum=pkg.checksum,
                min_app_version=pkg.min_app_version,
                lektion_count=pkg.lektion_count,
                exercise_count=pkg.exercise_count,
                published_at=pkg.published_at,
            )
        )
    return ManifestOut(entries=entries, server_time=now())


@router.get("/levels/{level_id}", response_model=PackageOut)
async def get_level_package(
    level_id: CefrLevel,
    version: Annotated[str | None, Query(max_length=32)] = None,
) -> PackageOut:
    if version is not None:
        pkg = await ContentPackage.find_one(
            ContentPackage.level_id == level_id,
            ContentPackage.version == version,
        )
        if pkg is None:
            raise NotFound(
                f"No content package {level_id.value}@{version}.",
                code=ErrorCode.CONTENT_VERSION_UNKNOWN,
            )
    else:
        pkg = (
            await ContentPackage.find(
                ContentPackage.level_id == level_id,
                ContentPackage.is_published == True,  # noqa: E712 - Beanie operator
            )
            .sort("-published_at")
            .first_or_none()
        )
        if pkg is None:
            raise NotFound(f"No published content for {level_id.value} yet.")

    return PackageOut(
        level_id=pkg.level_id,
        version=pkg.version,
        schema_version=pkg.schema_version,
        checksum=pkg.checksum,
        min_app_version=pkg.min_app_version,
        payload=pkg.payload,
    )


@router.post(
    "/packages", response_model=ManifestEntry, status_code=status.HTTP_201_CREATED
)
async def publish_package(
    body: PublishPackageRequest,
    x_admin_key: Annotated[str | None, Header(alias="X-Admin-Key")] = None,
) -> ManifestEntry:
    """Upsert a version of one level's content.

    Re-publishing an existing (level, version) overwrites it - deliberate, so a
    content fix during authoring does not need a version bump. Shipped versions
    should always get a new number.
    """
    await _require_admin(x_admin_key)

    checksum = canonical_checksum(body.payload)
    lektion_count, exercise_count = _count_nodes(body.payload)

    pkg = await ContentPackage.find_one(
        ContentPackage.level_id == body.level_id,
        ContentPackage.version == body.version,
    )
    if pkg is None:
        pkg = ContentPackage(
            level_id=body.level_id,
            version=body.version,
            schema_version=body.schema_version,
            checksum=checksum,
            payload=body.payload,
            min_app_version=body.min_app_version,
            notes=body.notes,
        )
    else:
        pkg.schema_version = body.schema_version
        pkg.checksum = checksum
        pkg.payload = body.payload
        pkg.min_app_version = body.min_app_version
        pkg.notes = body.notes

    pkg.lektion_count = lektion_count
    pkg.exercise_count = exercise_count
    pkg.is_published = body.publish
    pkg.published_at = now() if body.publish else None
    await pkg.save()

    return ManifestEntry(
        level_id=pkg.level_id,
        version=pkg.version,
        schema_version=pkg.schema_version,
        checksum=pkg.checksum,
        min_app_version=pkg.min_app_version,
        lektion_count=pkg.lektion_count,
        exercise_count=pkg.exercise_count,
        published_at=pkg.published_at,
    )
