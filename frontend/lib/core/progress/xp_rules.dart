import 'dart:math' as math;

/// XP and levelling, in one place.
///
/// Deliberately pure: no storage, no widgets, no clock reads passed implicitly.
/// The same rules have to run on the server once XP becomes
/// server-authoritative, so keeping them a set of total functions means they can
/// be ported without being reinterpreted.
///
/// Two numbers, and they must never be conflated:
///
///  * **XP** measures effort. Cumulative, never decreases, drives level.
///  * **Mastery** measures current retention. Moves both ways, decays without
///    review. Not implemented yet - see [masteryNotImplemented].

/// What an exercise demands of the learner. Base XP follows from this rather
/// than from which screen it happens to live on.
enum ExerciseClass {
  /// Pick from options: multiple choice, article pick, match.
  recognition,

  /// Produce the form from memory: typed fill-in, plural, article.
  recall,

  /// Hear it and reproduce it.
  listening,

  /// Build a sentence, translate into German.
  production,

  /// Free writing or speaking.
  free,
}

/// Why an attempt earned what it earned.
enum AttemptOutcome {
  /// First time this item has ever been answered correctly.
  firstCorrect,

  /// Correct, on an item whose review was actually due.
  dueReview,

  /// Correct, but the item was not due - practising ahead.
  aheadOfSchedule,

  /// Correct only after revealing a hint.
  hinted,

  /// Wrong. Earns nothing, but is still recorded.
  incorrect,
}

abstract final class XpRules {
  // --- base, by what the exercise demands ---------------------------------
  static const _base = <ExerciseClass, int>{
    ExerciseClass.recognition: 2,
    ExerciseClass.recall: 3,
    ExerciseClass.listening: 4,
    ExerciseClass.production: 5,
    ExerciseClass.free: 8,
  };

  /// Flat bonus for finishing a section with no wrong answers.
  static const perfectSectionBonus = 15;

  // --- outcome multipliers ------------------------------------------------
  static double outcomeMultiplier(AttemptOutcome outcome) => switch (outcome) {
        AttemptOutcome.firstCorrect => 1.0,
        // A review is worth less per repetition, but it repeats.
        AttemptOutcome.dueReview => 0.6,
        // Below a due review: drilling an item that is not due teaches less,
        // while still being worth something.
        AttemptOutcome.aheadOfSchedule => 0.4,
        AttemptOutcome.hinted => 0.5,
        AttemptOutcome.incorrect => 0.0,
      };

  // --- streak multiplier --------------------------------------------------
  /// Rewards consistency, capped so a long streak cannot dwarf the work.
  static double streakMultiplier(int streakDays) {
    if (streakDays >= 30) return 1.25;
    if (streakDays >= 7) return 1.1;
    return 1.0;
  }

  // --- daily diminishing returns -----------------------------------------
  /// Anti-grind. Applied to the *marginal* XP given how much has already been
  /// earned today, so no other multiplier can escape the cap.
  static double dailyReturnFactor({
    required int earnedToday,
    required int dailyGoalXp,
  }) {
    if (dailyGoalXp <= 0) return 1.0;
    if (earnedToday < dailyGoalXp) return 1.0;
    if (earnedToday < dailyGoalXp * 3) return 0.5;
    return 0.25;
  }

  /// XP for one attempt.
  ///
  /// Order matters and is fixed: base x outcome x streak, then diminishing
  /// returns last against the running daily total.
  static int award({
    required ExerciseClass exerciseClass,
    required AttemptOutcome outcome,
    required int streakDays,
    required int earnedToday,
    required int dailyGoalXp,
  }) {
    final base = _base[exerciseClass]!;
    final raw = base *
        outcomeMultiplier(outcome) *
        streakMultiplier(streakDays);
    if (raw == 0) return 0;

    final capped = raw *
        dailyReturnFactor(earnedToday: earnedToday, dailyGoalXp: dailyGoalXp);

    // Never round a non-zero award down to nothing: an attempt that earned
    // something must show something, or the rules feel broken.
    return math.max(1, capped.round());
  }

  // --- levels -------------------------------------------------------------

  /// Cumulative XP required to *reach* level [n]. Level 1 costs nothing.
  ///
  /// `80 * n^1.45`. The illustrative table in the brief drifts from this at
  /// n=5, 25 and 50; the formula is authoritative and lives only here.
  static int xpForLevel(int n) {
    if (n <= 1) return 0;
    return (80 * math.pow(n, 1.45)).round();
  }

  /// The level a given cumulative XP total has reached.
  static int levelForXp(int totalXp) {
    if (totalXp <= 0) return 1;
    var level = 1;
    // Monotonic curve, so walking up is exact and cheap at these magnitudes.
    while (xpForLevel(level + 1) <= totalXp) {
      level++;
      if (level > 999) break; // guard against a curve change making this loop
    }
    return level;
  }

  /// Progress through the current level, 0..1, plus the raw figures - a bar
  /// alone hides how much is actually left.
  static ({int level, int into, int needed, double fraction}) levelProgress(
    int totalXp,
  ) {
    final level = levelForXp(totalXp);
    final floor = xpForLevel(level);
    final ceiling = xpForLevel(level + 1);
    final span = ceiling - floor;
    final into = totalXp - floor;
    return (
      level: level,
      into: into,
      needed: span,
      fraction: span <= 0 ? 0 : (into / span).clamp(0.0, 1.0),
    );
  }

  /// Daily XP target implied by a minutes-per-day goal.
  ///
  /// Rough by design: about 3 XP per productive minute at these base values.
  /// It exists so diminishing returns have a threshold, not to be precise.
  static int dailyGoalXpFor(int goalMinutes) => math.max(10, goalMinutes * 3);

  /// Mastery / spaced repetition is not implemented. Named so the gap is
  /// visible in code rather than implied by its absence.
  static const masteryNotImplemented =
      'Mastery uses FSRS and needs per-item review history; see docs/BLOCKERS.md';
}
