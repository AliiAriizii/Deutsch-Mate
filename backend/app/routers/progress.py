"""Progress read + offline-tolerant sync."""

from __future__ import annotations

from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Query
from pymongo.errors import DuplicateKeyError

from ..deps import CurrentUser
from ..models.enums import ProgressStatus
from ..models.progress import (
    ExerciseAttempt,
    LektionProgress,
    SectionProgress,
    UserStats,
)
from ..models.user import User
from ..schemas.progress import (
    DueReviewOut,
    LektionProgressOut,
    SectionProgressOut,
    StatsOut,
    SyncRequest,
    SyncResponse,
)
from ..security import now

router = APIRouter(prefix="/progress", tags=["progress"])

# Ordered weakest -> strongest, so a merge can only move a Lektion forward.
_STATUS_RANK = {
    ProgressStatus.LOCKED: 0,
    ProgressStatus.AVAILABLE: 1,
    ProgressStatus.IN_PROGRESS: 2,
    ProgressStatus.COMPLETED: 3,
}


def _progress_out(doc: LektionProgress) -> LektionProgressOut:
    return LektionProgressOut(
        level_id=doc.level_id,
        lektion_id=doc.lektion_id,
        modul_id=doc.modul_id,
        status=doc.status,
        sections=[
            SectionProgressOut(
                kind=s.kind,
                completed=s.completed,
                correct_count=s.correct_count,
                total_count=s.total_count,
                completed_at=s.completed_at,
            )
            for s in doc.sections
        ],
        xp_earned=doc.xp_earned,
        best_score_percent=doc.best_score_percent,
        attempt_count=doc.attempt_count,
        seconds_spent=doc.seconds_spent,
        revision=doc.revision,
        started_at=doc.started_at,
        first_completed_at=doc.first_completed_at,
        last_activity_at=doc.last_activity_at,
    )


def _stats_out(stats: UserStats) -> StatsOut:
    return StatsOut(
        total_xp=stats.total_xp,
        current_streak=stats.current_streak,
        longest_streak=stats.longest_streak,
        last_active_date=stats.last_active_date,
        minutes_studied=stats.minutes_studied,
        lektionen_completed=stats.lektionen_completed,
        words_learned=stats.words_learned,
    )


async def _get_or_create_stats(user: User) -> UserStats:
    stats = await UserStats.find_one(UserStats.user_id == user.id)
    if stats is None:
        stats = UserStats(user_id=user.id)
        await stats.insert()
    return stats


@router.get("", response_model=SyncResponse)
async def read_progress(user: CurrentUser) -> SyncResponse:
    docs = await LektionProgress.find(LektionProgress.user_id == user.id).to_list()
    stats = await _get_or_create_stats(user)
    return SyncResponse(
        lektionen=[_progress_out(d) for d in docs],
        stats=_stats_out(stats),
        attempts_accepted=0,
        attempts_duplicate=0,
        server_time=now(),
    )


@router.post("/sync", response_model=SyncResponse)
async def sync_progress(body: SyncRequest, user: CurrentUser) -> SyncResponse:
    """Merge a batch of offline work.

    Monotonic fields take the maximum of the two sides and status can only move
    forward, so replaying an old batch from a stale device cannot roll anything
    back. Attempts are deduplicated on ``client_attempt_id``.
    """
    for incoming in body.lektionen:
        doc = await LektionProgress.find_one(
            LektionProgress.user_id == user.id,
            LektionProgress.lektion_id == incoming.lektion_id,
        )
        if doc is None:
            doc = LektionProgress(
                user_id=user.id,
                level_id=incoming.level_id,
                lektion_id=incoming.lektion_id,
                modul_id=incoming.modul_id,
                status=incoming.status,
                started_at=now(),
            )

        doc.level_id = incoming.level_id
        doc.modul_id = incoming.modul_id

        if _STATUS_RANK[incoming.status] > _STATUS_RANK[doc.status]:
            doc.status = incoming.status

        doc.xp_earned = max(doc.xp_earned, incoming.xp_earned)
        doc.best_score_percent = max(
            doc.best_score_percent, incoming.best_score_percent
        )
        doc.seconds_spent = max(doc.seconds_spent, incoming.seconds_spent)
        doc.revision = max(doc.revision, incoming.revision)
        doc.attempt_count += 1
        doc.last_activity_at = incoming.last_activity_at or now()
        if doc.started_at is None:
            doc.started_at = doc.last_activity_at

        # Section merge: a section that is complete anywhere stays complete.
        by_kind = {s.kind: s for s in doc.sections}
        for section in incoming.sections:
            existing = by_kind.get(section.kind)
            if existing is None:
                by_kind[section.kind] = SectionProgress(
                    kind=section.kind,
                    completed=section.completed,
                    completed_at=now() if section.completed else None,
                    correct_count=section.correct_count,
                    total_count=section.total_count,
                )
                continue
            if section.completed and not existing.completed:
                existing.completed = True
                existing.completed_at = now()
            existing.correct_count = max(existing.correct_count, section.correct_count)
            existing.total_count = max(existing.total_count, section.total_count)
        doc.sections = list(by_kind.values())

        if doc.status is ProgressStatus.COMPLETED and doc.first_completed_at is None:
            doc.first_completed_at = now()

        await doc.save()

    accepted = 0
    duplicate = 0
    for attempt in body.attempts:
        try:
            await ExerciseAttempt(
                user_id=user.id,
                lektion_id=attempt.lektion_id,
                section_kind=attempt.section_kind,
                exercise_id=attempt.exercise_id,
                is_correct=attempt.is_correct,
                given_answer=attempt.given_answer,
                response_ms=attempt.response_ms,
                leitner_box=attempt.leitner_box,
                due_at=attempt.due_at,
                attempted_at=attempt.attempted_at or now(),
                client_attempt_id=attempt.client_attempt_id,
            ).insert()
            accepted += 1
        except DuplicateKeyError:
            # Same batch re-sent after a flaky connection - not an error.
            duplicate += 1

    stats = await _get_or_create_stats(user)
    docs = await LektionProgress.find(LektionProgress.user_id == user.id).to_list()

    stats.total_xp = sum(d.xp_earned for d in docs)
    stats.lektionen_completed = sum(
        1 for d in docs if d.status is ProgressStatus.COMPLETED
    )
    stats.minutes_studied += body.minutes_studied_delta

    if body.active_date is not None:
        previous = stats.last_active_date
        if previous is None:
            stats.current_streak = 1
        elif body.active_date == previous:
            pass  # same day, streak unchanged
        elif body.active_date == previous + timedelta(days=1):
            stats.current_streak += 1
        elif body.active_date > previous:
            stats.current_streak = 1
        if body.active_date >= (previous or body.active_date):
            stats.last_active_date = body.active_date
        stats.longest_streak = max(stats.longest_streak, stats.current_streak)

    stats.updated_at = now()
    await stats.save()

    return SyncResponse(
        lektionen=[_progress_out(d) for d in docs],
        stats=_stats_out(stats),
        attempts_accepted=accepted,
        attempts_duplicate=duplicate,
        server_time=now(),
    )


@router.get("/due-reviews", response_model=list[DueReviewOut])
async def due_reviews(
    user: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> list[DueReviewOut]:
    """Leitner items whose interval has elapsed, oldest first."""
    docs = (
        await ExerciseAttempt.find(
            ExerciseAttempt.user_id == user.id,
            ExerciseAttempt.due_at != None,  # noqa: E711 - Beanie query operator
            ExerciseAttempt.due_at <= now(),
        )
        .sort("+due_at")
        .limit(limit)
        .to_list()
    )
    # One row per exercise: the newest attempt is the one that matters.
    seen: set[str] = set()
    out: list[DueReviewOut] = []
    for d in docs:
        if d.exercise_id in seen:
            continue
        seen.add(d.exercise_id)
        out.append(
            DueReviewOut(
                exercise_id=d.exercise_id,
                lektion_id=d.lektion_id,
                section_kind=d.section_kind,
                leitner_box=d.leitner_box,
                due_at=d.due_at,
            )
        )
    return out
