"""Progress: per user, per Lektion, per exercise.

Survives reinstall because it lives here, keyed by account - never on the
device only. The device keeps a local mirror (Drift) and reconciles through
``/progress/sync``.
"""

from __future__ import annotations

from datetime import date, datetime

from beanie import Document, PydanticObjectId
from pydantic import BaseModel, Field
from pymongo import ASCENDING, DESCENDING, IndexModel

from ..security import now
from .enums import CefrLevel, ProgressStatus, SectionKind


class SectionProgress(BaseModel):
    kind: SectionKind
    completed: bool = False
    completed_at: datetime | None = None
    correct_count: int = 0
    total_count: int = 0


class LektionProgress(Document):
    user_id: PydanticObjectId
    level_id: CefrLevel
    # Stable content id, e.g. "a1.1.m1.l3" - never a positional index.
    lektion_id: str
    modul_id: str

    status: ProgressStatus = ProgressStatus.AVAILABLE
    sections: list[SectionProgress] = Field(default_factory=list)

    xp_earned: int = 0
    best_score_percent: int = 0
    attempt_count: int = 0
    seconds_spent: int = 0

    started_at: datetime | None = None
    first_completed_at: datetime | None = None
    last_activity_at: datetime = Field(default_factory=now)

    # Monotonic per (user, lektion). Lets the client push offline work without
    # an older device clobbering newer server state.
    revision: int = 0

    class Settings:
        name = "lektion_progress"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("lektion_id", ASCENDING)],
                unique=True,
                name="uq_progress_user_lektion",
            ),
            IndexModel(
                [("user_id", ASCENDING), ("level_id", ASCENDING)],
                name="ix_progress_user_level",
            ),
            IndexModel(
                [("user_id", ASCENDING), ("last_activity_at", DESCENDING)],
                name="ix_progress_user_recent",
            ),
        ]


class ExerciseAttempt(Document):
    user_id: PydanticObjectId
    lektion_id: str
    section_kind: SectionKind
    exercise_id: str

    is_correct: bool
    given_answer: str | None = None
    response_ms: int | None = None
    # Leitner box 0..5 for spaced repetition; None for non-review exercises.
    leitner_box: int | None = Field(default=None, ge=0, le=5)
    due_at: datetime | None = None

    attempted_at: datetime = Field(default_factory=now)
    # Client-generated id, so a retried sync cannot double-count an attempt.
    client_attempt_id: str | None = None

    class Settings:
        name = "exercise_attempts"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("exercise_id", ASCENDING)],
                name="ix_attempt_user_exercise",
            ),
            IndexModel(
                [("user_id", ASCENDING), ("due_at", ASCENDING)],
                name="ix_attempt_user_due",
            ),
            IndexModel(
                [("client_attempt_id", ASCENDING)],
                unique=True,
                sparse=True,
                name="uq_attempt_client_id",
            ),
        ]


class UserStats(Document):
    user_id: PydanticObjectId

    total_xp: int = 0
    current_streak: int = 0
    longest_streak: int = 0
    last_active_date: date | None = None
    minutes_studied: int = 0
    lektionen_completed: int = 0
    words_learned: int = 0

    updated_at: datetime = Field(default_factory=now)

    class Settings:
        name = "user_stats"
        indexes = [
            IndexModel([("user_id", ASCENDING)], unique=True, name="uq_stats_user"),
        ]
