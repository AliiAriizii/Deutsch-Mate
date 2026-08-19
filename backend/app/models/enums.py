"""Vocabulary shared by documents, request/response schemas, and the content
schema the Flutter client validates against.

These strings are a contract: they appear verbatim in content JSON and in the
client. Adding a member is safe; renaming one is a content migration.
"""

from enum import StrEnum


class CefrLevel(StrEnum):
    """The six Menschen half-volumes, A1.1 -> B1.2."""

    A1_1 = "A1.1"
    A1_2 = "A1.2"
    A2_1 = "A2.1"
    A2_2 = "A2.2"
    B1_1 = "B1.1"
    B1_2 = "B1.2"


LEVEL_ORDER: tuple[CefrLevel, ...] = (
    CefrLevel.A1_1,
    CefrLevel.A1_2,
    CefrLevel.A2_1,
    CefrLevel.A2_2,
    CefrLevel.B1_1,
    CefrLevel.B1_2,
)


class SectionKind(StrEnum):
    """The five-part internal shape mirrored from every Menschen Lektion."""

    EINSTIEG = "einstieg"
    WORTSCHATZ = "wortschatz"
    GRAMMATIK = "grammatik"
    REDEMITTEL = "redemittel"
    ABSCHLUSS = "abschluss"


class ModulPlusKind(StrEnum):
    """The four closing sections of every Modul."""

    LESEMAGAZIN = "lesemagazin"
    FILM = "film"
    PROJEKT = "projekt"
    AUSKLANG = "ausklang"


class ExerciseType(StrEnum):
    """Closed set. Each member has exactly one Dart renderer in the client, so
    new *content* needs no Dart change - only a new *type* would.
    """

    MCQ = "mcq"
    ARTICLE_PICK = "article_pick"
    CLOZE = "cloze"
    TRANSLATE_WRITE = "translate_write"
    FLASHCARD = "flashcard"
    ORDER_WORDS = "order_words"
    LISTEN_TYPE = "listen_type"
    MATCH_PAIRS = "match_pairs"


class ProgressStatus(StrEnum):
    LOCKED = "locked"
    AVAILABLE = "available"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"


class UserStatus(StrEnum):
    ACTIVE = "active"
    DISABLED = "disabled"
    PENDING_DELETION = "pending_deletion"


class InterfaceLanguage(StrEnum):
    FA = "fa"
    EN = "en"
    DE = "de"


class TokenPurpose(StrEnum):
    EMAIL_VERIFY = "email_verify"
    PASSWORD_RESET = "password_reset"
