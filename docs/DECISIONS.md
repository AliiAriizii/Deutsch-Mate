# Decisions

> Blocker resolutions and the v2 spec conflicts are in
> [BLOCKERS.md](BLOCKERS.md). Android signing is in [SIGNING.md](SIGNING.md).

Answers to the open questions from the Phase 1 audit. Items marked **you** were
your call; the rest I decided as asked.

## Settled by you

| # | Question | Decision |
|---|---|---|
| G1 | Backend | **Local Python backend, MongoDB.** FastAPI + Beanie ODM. Built - see [backend/README.md](../backend/README.md) |
| — | Flutter SDK | **Installed.** 3.47.0 stable at `C:\Users\Banaizade\flutter`, on the user PATH |
| — | App identifier | **`com.deutschmate.app`** - product-owned, independent of any company. Applied to Android, iOS, macOS, Linux, Windows. Permanent after the first store upload |
| — | Release signing | **Deferred.** Still the debug keystore. Blocks store upload only; a real upload key does not belong in the repository |

## Decided here

### G2 — Content updates without an app-store release

Bundled JSON alone cannot do it, so content is **bundled *and* served**:

- Each level ships as a bundled asset, so a cold first launch works fully offline.
- On launch the app calls `GET /content/manifest` and compares each level's
  `version` against its cached copy.
- Only changed levels are downloaded, then verified against `checksum`
  (SHA-256 over canonical JSON — sorted keys, tight separators, so both sides
  always compute the same digest).
- `min_app_version` on a package stops content from reaching an app whose
  renderer set is too old.

### G3 — The "spine of light"

**Mirrored, direction-aware.** The spine hangs off the *start* edge, so it sits
left in `en`/`de` and right in `fa`. Anything else looks like a rendering bug to
a Persian reader. Implemented with `EdgeInsetsDirectional` /
`AlignmentDirectional` and never `left:`/`right:`.

It also needs somewhere to live: there is no Lektion path screen today
(LearnScreen is a flat `ListView`). Building it is explicit Phase 3 scope, not a
restyle of something existing.

### G4 — Localisation

**Infrastructure lands at the end of Phase 2; string extraction happens inside
Phase 3.**

Reasoning: Phase 3 already opens all 13 screens to restyle them. Extracting the
~107 inline Persian literals in that same pass costs almost nothing, whereas a
separate localisation phase would open every file a second time. But the ARB
files and `flutter_localizations` have to exist *before* Phase 3 starts, or
there is nowhere to put the strings — so the plumbing goes in at the tail of
Phase 2.

- Locales: `fa` (default), `en`, `de`.
- `fa` is RTL — the whole restyle gets checked in both directions, not retrofitted.
- Interface language from onboarding drives `MaterialApp.locale`, and the
  backend already persists it on the user record.

### G5 — Spacing and radii tokens

`ThemeData` has no slot for spacing, so a literal reading of
"no hardcoded spacing outside the theme layer" is unachievable. Using two
`ThemeExtension`s instead:

```dart
theme.extension<AppSpacing>()!.md    // 4pt grid: 4, 8, 12, 16, 24, 32, 48
theme.extension<AppRadii>()!.card    // card 12, control 10, pill 999
```

Same guarantee as the colour rule — one definition, zero magic numbers in
widgets, and it still grep-checks clean.

### G6 — Fonts

All **bundled as static files**, and `google_fonts` gets dropped. The package
fetches at runtime, which directly contradicts offline-first.

| Role | Face | Licence |
|---|---|---|
| Display (page titles, Lektion numerals) | **Bricolage Grotesque** | OFL |
| Body / UI | **Instrument Sans** | OFL |
| Tables (conjugations, article markers, Redemittel) | **JetBrains Mono** | OFL |
| Persian UI | **Vazirmatn** | OFL |

- *General Sans* was rejected: Fontshare, not OFL, separate licence review.
- Every face gets checked for `ä ö ü Ä Ö Ü ß` before it lands.
- Vazirmatn has no monospace cut, so Persian cells in grammar tables use
  Vazirmatn with fixed column widths while the German column stays JetBrains
  Mono. Monospacing the German is what makes the table scannable; forcing it on
  Persian would just break the shaping.

### G7 — Exercise types (closed set)

Eight, each with exactly one Dart renderer. New content then needs **zero** Dart;
only a new *type* would.

`mcq` · `article_pick` · `cloze` · `translate_write` · `flashcard` ·
`order_words` · `listen_type` · `match_pairs`

Already encoded server-side in `app/models/enums.py::ExerciseType`, so content
that names an unknown type fails validation instead of failing at runtime.

### G8 — On-device database

**Drift (SQLite).** Hive is unmaintained and Isar is stalled, and the unlock
logic needs real relational queries over `prerequisiteIds` plus per-exercise
progress. `hive`/`hive_flutter` get dropped from `pubspec.yaml` — they were
declared but never used.

### G9 — Placement test

**Manual level override ships first; the adaptive test comes in Phase 6.**
Onboarding's target level already seeds `placement_level`, so a B1.1 starter is
never walked through A1.1. The test needs an item bank and a scoring-to-level
mapping, which is content work, and gating v1 on it would block everything else.

### G10 — Dependency and lint cleanup (Phase 0)

- `flutter_lints` 3.0.2 → 6.x
- Drop unused: `flutter_bloc`, `hive`, `hive_flutter`, `google_fonts`,
  `path_provider` (5 of 8 declared deps were dead)
- Fix 11 deprecated `withOpacity` → `withValues`
- Remove 4 `print()` calls, one of which logged every stored password
- Fix `test/widget_test.dart` (references `MyApp`; the class is `DeutschMateApp`)
- Create `assets/data/` + `assets/audio/` (declared in pubspec, never existed)
- `git init` — this is not a repository yet, so "small reviewable commits" is
  currently impossible

### Content licensing

The 12 `name` values in `AppData.lessons` are **verbatim Hueber Menschen A1.1
Kursbuch Lektion titles**. They get replaced with original titles during the
Phase 5 migration. The syllabus *structure* — level sequence, 4 Module × 3
Lektionen, grammar progression, can-do goals — is mirrored, which is not
protectable and is what makes the app line up with a classroom course.

`README.md` at the repo root is not a readme: it is a 69-entry German→Persian
vocabulary dump with IPA and no stated source. It gets moved to
`docs/legacy/unsourced_vocab_dump.md`, excluded from shipped content, and stays
out of the app until you can tell me where it came from. Shipped vocabulary
comes from open-licensed sources (Wiktionary / Kaikki, CC BY-SA) with attribution.

## Revised phase plan

| Phase | Scope | State |
|---|---|---|
| 0 | Repo hygiene: `git init`, dead deps, lint fixes, broken test, missing asset dirs, app identity | **done** (`flutter analyze` clean, 2/2 tests, APK builds) |
| 1 | Audit + gap report | **done** |
| — | Flutter SDK install | **done** (3.47.0) |
| — | Android SDK install | **done** (platform 36, build-tools 36.0.0, NDK 28.2, licences accepted) |
| — | Backend: auth, progress, versioned content | **done** (41 tests green) |
| 2 | Theme system: tokens, typography, component themes, dark + light, l10n plumbing | awaiting go-ahead |
| 3 | Screen-by-screen restyle + string extraction + Lektion path with the spine | after 2 |
| 4 | Flutter auth client against this API: secure storage, silent refresh, onboarding | after 3 |
| 5 | Content schema + validator, Drift mirror, migrate off `AppData`, reference Lektion | after 4 |
| 6 | 72-Lektion syllabus map, original authored content, placement test | after 5 |
