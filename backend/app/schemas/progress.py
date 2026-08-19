"""Request/response bodies for progress sync."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field

from ..models.enums import CefrLevel, ProgressStatus, SectionKind


class SectionProgressIn(BaseModel):
    kind: SectionKind
    completed: bool = False
    correct_count: int = Field(default=0, ge=0)
    total_count: int = Field(default=0, ge=0)


class LektionProgressIn(BaseModel):
    level_id: CefrLevel
    lektion_id: str = Field(min_length=1, max_length=64)
    modul_id: str = Field(min_length=1, max_length=64)
    status: ProgressStatus
    sections: list[SectionProgressIn] = Field(default_factory=list)
    xp_earned: int = Field(default=0, ge=0)
    best_score_percent: int = Field(default=0, ge=0, le=100)
    seconds_spent: int = Field(default=0, ge=0)
    # Client's revision counter for this Lektion. The server keeps whichever
    # side is higher, so an offline device cannot roll back newer progress.
    revision: int = Field(default=0, ge=0)
    last_activity_at: datetime | None = None


class ExerciseAttemptIn(BaseModel):
    lektion_id: str = Field(min_length=1, max_length=64)
    section_kind: SectionKind
    exercise_id: str = Field(min_length=1, max_length=96)
    is_correct: bool
    given_answer: str | None = Field(default=None, max_length=512)
    response_ms: int | None = Field(default=None, ge=0)
    leitner_box: int | None = Field(default=None, ge=0, le=5)
    due_at: datetime | None = None
    attempted_at: datetime | None = None
    # Idempotency key. Re-sending the same batch cannot double-count.
    client_attempt_id: str = Field(min_length=1, max_length=64)


class SyncRequest(BaseModel):
    lektionen: list[LektionProgressIn] = Field(default_factory=list, max_length=500)
    attempts: list[ExerciseAttemptIn] = Field(default_factory=list, max_length=1000)
    minutes_studied_delta: int = Field(default=0, ge=0, le=1440)
    active_date: date | None = None


class SectionProgressOut(SectionProgressIn):
    completed_at: datetime | None = None


class LektionProgressOut(BaseModel):
    level_id: CefrLevel
    lektion_id: str
    modul_id: str
    status: ProgressStatus
    sections: list[SectionProgressOut]
    xp_earned: int
    best_score_percent: int
    attempt_count: int
    seconds_spent: int
    revision: int
    started_at: datetime | None
    first_completed_at: datetime | None
    last_activity_at: datetime


class StatsOut(BaseModel):
    total_xp: int
    current_streak: int
    longest_streak: int
    last_active_date: date | None
    minutes_studied: int
    lektionen_completed: int
    words_learned: int


class SyncResponse(BaseModel):
    """Authoritative post-merge state. The client replaces its mirror with this
    rather than trying to reconcile field by field."""

    lektionen: list[LektionProgressOut]
    stats: StatsOut
    attempts_accepted: int
    attempts_duplicate: int
    server_time: datetime


class DueReviewOut(BaseModel):
    exercise_id: str
    lektion_id: str
    section_kind: SectionKind
    leitner_box: int | None
    due_at: datetime | None
