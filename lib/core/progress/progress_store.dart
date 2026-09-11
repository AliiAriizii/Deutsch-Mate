import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lektion_plan.dart';
import 'progress_models.dart';
import 'xp_rules.dart';

/// Owns everything the learner has done.
///
/// Local-first and persisted. The JSON it writes is deliberately shaped like
/// the server's `/progress/sync` body, so wiring the backend later is a
/// transport change rather than a remodelling.
///
/// **Why SharedPreferences and not Drift.** docs/DECISIONS.md picks Drift, and
/// that still holds for the full 72-Lektion, ~2,400-word content set, where
/// paged relational queries matter. At today's size - 12 Lektionen and a
/// handful of counters - a single JSON document is the honest choice: no
/// codegen, no migrations, and it is trivially replaceable. The moment
/// per-item review scheduling lands, this becomes a Drift table.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this._plans, this._byLektion, this._stats);

  final SharedPreferences? _prefs;
  final List<LektionPlan> _plans;
  final Map<String, LektionProgress> _byLektion;
  LearnerStats _stats;

  static const _key = 'learner_progress_v1';

  /// Loads before the first frame that needs it.
  static Future<ProgressStore> load({
    List<LektionPlan>? plans,
    SharedPreferences? prefs,
  }) async {
    final resolved = plans ?? buildLektionPlans();
    SharedPreferences? store = prefs;
    try {
      store ??= await SharedPreferences.getInstance();
    } catch (e) {
      // A read failure must not block launch; the session simply starts empty.
      debugPrint('Progress store unavailable: ${e.runtimeType}');
    }

    final map = <String, LektionProgress>{};
    var stats = const LearnerStats();

    final raw = store?.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final item in (decoded['lektionen'] as List? ?? const [])) {
          final progress =
              LektionProgress.fromJson(Map<String, dynamic>.from(item as Map));
          map[progress.lektionId] = progress;
        }
        if (decoded['stats'] is Map) {
          stats = LearnerStats.fromJson(
            Map<String, dynamic>.from(decoded['stats'] as Map),
          );
        }
      } catch (e) {
        // Corrupt payload: start over rather than crash on every launch.
        debugPrint('Progress payload unreadable, resetting: ${e.runtimeType}');
      }
    }

    final instance = ProgressStore._(store, resolved, map, stats);
    instance._rollOverDayIfNeeded();
    return instance;
  }

  // ------------------------------------------------------------- reading --

  List<LektionPlan> get plans => List.unmodifiable(_plans);
  LearnerStats get stats => _stats;

  int get level => XpRules.levelForXp(_stats.totalXp);
  ({int level, int into, int needed, double fraction}) get levelProgress =>
      XpRules.levelProgress(_stats.totalXp);

  int get dailyGoalXp => XpRules.dailyGoalXpFor(_stats.dailyGoalMinutes);

  /// Fraction of today's goal met, 0..1.
  double get todayFraction =>
      dailyGoalXp == 0 ? 0 : (_stats.xpToday / dailyGoalXp).clamp(0.0, 1.0);

  bool get dailyGoalMet => _stats.xpToday >= dailyGoalXp;

  LektionProgress progressFor(LektionPlan plan) =>
      _byLektion[plan.lektionId] ??
      LektionProgress(
        lektionId: plan.lektionId,
        levelId: plan.levelId,
        modulId: plan.modulId,
      );

  int get completedLektionen => _plans
      .where((p) => progressFor(p).status == LektionStatus.completed)
      .length;

  double get courseFraction =>
      _plans.isEmpty ? 0 : completedLektionen / _plans.length;

  /// A Lektion is open once the one before it is finished. The first is always
  /// open, so a new learner is never staring at a wall of locks.
  bool isUnlocked(LektionPlan plan) {
    if (plan.index == 0) return true;
    final previous = _plans[plan.index - 1];
    return progressFor(previous).status == LektionStatus.completed;
  }

  LektionStatus statusFor(LektionPlan plan) {
    final stored = progressFor(plan);
    if (stored.status == LektionStatus.completed) return LektionStatus.completed;
    if (!isUnlocked(plan)) return LektionStatus.locked;
    return stored.completedSectionCount > 0
        ? LektionStatus.inProgress
        : LektionStatus.available;
  }

  /// The Lektion the learner should be looking at: the first unfinished one
  /// that is unlocked.
  LektionPlan? get currentLektion {
    for (final plan in _plans) {
      if (statusFor(plan) != LektionStatus.completed && isUnlocked(plan)) {
        return plan;
      }
    }
    return null;
  }

  /// The exact next thing to do: which Lektion, which section. This is what
  /// makes "how do I progress" answerable in one line of UI.
  ({LektionPlan plan, SectionKind section})? get nextStep {
    final plan = currentLektion;
    if (plan == null) return null;
    final progress = progressFor(plan);
    for (final step in plan.steps) {
      if (!progress.isSectionDone(step)) return (plan: plan, section: step);
    }
    return null;
  }

  // ------------------------------------------------------------- writing --

  /// Marks one section done and awards its XP.
  ///
  /// [correct] and [total] describe how the learner did, so a section finished
  /// flawlessly can earn the perfect bonus.
  Future<int> completeSection({
    required LektionPlan plan,
    required SectionKind section,
    int correct = 0,
    int total = 0,
  }) async {
    final existing = progressFor(plan);
    if (existing.isSectionDone(section)) return 0;

    // Reading through a word field is recognition; producing sentences is
    // production. The class drives the XP, not the screen it happened on.
    final exerciseClass = switch (section) {
      SectionKind.wortschatz => ExerciseClass.recognition,
      SectionKind.grammatik => ExerciseClass.recall,
      SectionKind.redemittel => ExerciseClass.production,
      _ => ExerciseClass.recognition,
    };

    final items = total > 0 ? total : plan.itemsIn(section).clamp(1, 40);
    var earned = 0;
    for (var i = 0; i < items; i++) {
      earned += XpRules.award(
        exerciseClass: exerciseClass,
        outcome: AttemptOutcome.firstCorrect,
        streakDays: _stats.currentStreak,
        earnedToday: _stats.xpToday + earned,
        dailyGoalXp: dailyGoalXp,
      );
    }
    if (total > 0 && correct == total) {
      earned += XpRules.perfectSectionBonus;
    }

    final sections = [
      ...existing.sections.where((s) => s.kind != section),
      SectionProgress(
        kind: section,
        completed: true,
        correct: correct,
        total: total,
        completedAt: DateTime.now(),
      ),
    ];

    final allDone = plan.steps.every(
      (step) => sections.any((s) => s.kind == step && s.completed),
    );

    _byLektion[plan.lektionId] = existing.copyWith(
      sections: sections,
      status: allDone ? LektionStatus.completed : LektionStatus.inProgress,
      xpEarned: existing.xpEarned + earned,
      revision: existing.revision + 1,
      lastActivityAt: DateTime.now(),
      firstCompletedAt: allDone && existing.firstCompletedAt == null
          ? DateTime.now()
          : existing.firstCompletedAt,
    );

    await _addXp(earned);
    return earned;
  }

  /// XP from a practice drill, which belongs to no particular Lektion.
  Future<int> recordDrillAttempt({
    required ExerciseClass exerciseClass,
    required bool correct,
    bool usedHint = false,
  }) async {
    final earned = XpRules.award(
      exerciseClass: exerciseClass,
      outcome: !correct
          ? AttemptOutcome.incorrect
          : usedHint
              ? AttemptOutcome.hinted
              // No review schedule yet, so a correct drill answer is priced as
              // practising ahead rather than as a due review.
              : AttemptOutcome.aheadOfSchedule,
      streakDays: _stats.currentStreak,
      earnedToday: _stats.xpToday,
      dailyGoalXp: dailyGoalXp,
    );
    if (earned > 0) await _addXp(earned);
    return earned;
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    _stats = _stats.copyWith(dailyGoalMinutes: minutes);
    await _persist();
  }

  /// Wipes everything. Used by "start over" and by sign-out.
  Future<void> reset() async {
    _byLektion.clear();
    _stats = const LearnerStats();
    await _persist();
  }

  // ------------------------------------------------------------ internals --

  Future<void> _addXp(int earned) async {
    _rollOverDayIfNeeded();

    final today = _today();
    final previous = _stats.lastActiveDay;

    var streak = _stats.currentStreak;
    if (previous == null) {
      streak = 1;
    } else {
      final gap = today.difference(previous).inDays;
      if (gap == 1) {
        streak += 1;
      } else if (gap > 1) {
        streak = 1;
      }
      // gap == 0: same day, streak unchanged.
    }

    _stats = _stats.copyWith(
      totalXp: _stats.totalXp + earned,
      xpToday: _stats.xpToday + earned,
      lastActiveDay: today,
      currentStreak: streak,
      longestStreak: streak > _stats.longestStreak ? streak : _stats.longestStreak,
    );
    await _persist();
  }

  /// Today's XP resets at local midnight. Without this, "XP today" would keep
  /// climbing across days and diminishing returns would never lift.
  void _rollOverDayIfNeeded() {
    final last = _stats.lastActiveDay;
    if (last != null && _today().difference(last).inDays != 0) {
      _stats = _stats.copyWith(xpToday: 0);
    }
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _persist() async {
    notifyListeners();
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        _key,
        jsonEncode({
          'lektionen': [for (final p in _byLektion.values) p.toJson()],
          'stats': _stats.toJson(),
        }),
      );
    } catch (e) {
      // The in-memory state is already correct; losing the write costs the
      // next launch, not this session.
      debugPrint('Progress not saved: ${e.runtimeType}');
    }
  }
}
