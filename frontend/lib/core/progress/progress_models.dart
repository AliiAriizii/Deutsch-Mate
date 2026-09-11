import 'package:flutter/foundation.dart';

/// The five-part shape of a Menschen Lektion.
///
/// The current content only carries material for three of them. Rather than
/// invent the missing two, [LektionPlan] reports which sections actually have
/// something to do, so the UI never shows a step a learner cannot take.
enum SectionKind { einstieg, wortschatz, grammatik, redemittel, abschluss }

extension SectionKindLabel on SectionKind {
  /// The German name, which is what the book uses and what the eyebrow shows.
  String get german => switch (this) {
        SectionKind.einstieg => 'Einstieg',
        SectionKind.wortschatz => 'Wortschatz',
        SectionKind.grammatik => 'Grammatik',
        SectionKind.redemittel => 'Redemittel',
        SectionKind.abschluss => 'Abschluss',
      };

  String get persian => switch (this) {
        SectionKind.einstieg => 'آشنایی',
        SectionKind.wortschatz => 'واژگان',
        SectionKind.grammatik => 'ساختار',
        SectionKind.redemittel => 'جمله‌ها',
        SectionKind.abschluss => 'جمع‌بندی',
      };
}

/// How far along one section is.
@immutable
class SectionProgress {
  const SectionProgress({
    required this.kind,
    this.completed = false,
    this.correct = 0,
    this.total = 0,
    this.completedAt,
  });

  final SectionKind kind;
  final bool completed;
  final int correct;
  final int total;
  final DateTime? completedAt;

  double get accuracy => total == 0 ? 0 : correct / total;

  SectionProgress copyWith({
    bool? completed,
    int? correct,
    int? total,
    DateTime? completedAt,
  }) =>
      SectionProgress(
        kind: kind,
        completed: completed ?? this.completed,
        correct: correct ?? this.correct,
        total: total ?? this.total,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'completed': completed,
        'correct': correct,
        'total': total,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      };

  factory SectionProgress.fromJson(Map<String, dynamic> json) =>
      SectionProgress(
        kind: SectionKind.values.byName(json['kind'] as String),
        completed: json['completed'] == true,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.tryParse(json['completed_at'] as String),
      );
}

enum LektionStatus { locked, available, inProgress, completed }

/// One Lektion's progress.
///
/// Field names mirror the server's `/progress/sync` payload, so pushing this
/// to the backend later is a transport change rather than a remodelling.
@immutable
class LektionProgress {
  const LektionProgress({
    required this.lektionId,
    required this.levelId,
    required this.modulId,
    this.status = LektionStatus.available,
    this.sections = const [],
    this.xpEarned = 0,
    this.secondsSpent = 0,
    this.revision = 0,
    this.lastActivityAt,
    this.firstCompletedAt,
  });

  final String lektionId;
  final String levelId;
  final String modulId;
  final LektionStatus status;
  final List<SectionProgress> sections;
  final int xpEarned;
  final int secondsSpent;

  /// Monotonic per Lektion. The server keeps whichever side is higher, so an
  /// offline device can never roll newer progress back.
  final int revision;

  final DateTime? lastActivityAt;
  final DateTime? firstCompletedAt;

  SectionProgress? section(SectionKind kind) =>
      sections.where((s) => s.kind == kind).firstOrNull;

  bool isSectionDone(SectionKind kind) => section(kind)?.completed ?? false;

  int get completedSectionCount => sections.where((s) => s.completed).length;

  LektionProgress copyWith({
    LektionStatus? status,
    List<SectionProgress>? sections,
    int? xpEarned,
    int? secondsSpent,
    int? revision,
    DateTime? lastActivityAt,
    DateTime? firstCompletedAt,
  }) =>
      LektionProgress(
        lektionId: lektionId,
        levelId: levelId,
        modulId: modulId,
        status: status ?? this.status,
        sections: sections ?? this.sections,
        xpEarned: xpEarned ?? this.xpEarned,
        secondsSpent: secondsSpent ?? this.secondsSpent,
        revision: revision ?? this.revision,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
        firstCompletedAt: firstCompletedAt ?? this.firstCompletedAt,
      );

  Map<String, dynamic> toJson() => {
        'lektion_id': lektionId,
        'level_id': levelId,
        'modul_id': modulId,
        'status': status.name,
        'sections': [for (final s in sections) s.toJson()],
        'xp_earned': xpEarned,
        'seconds_spent': secondsSpent,
        'revision': revision,
        if (lastActivityAt != null)
          'last_activity_at': lastActivityAt!.toIso8601String(),
        if (firstCompletedAt != null)
          'first_completed_at': firstCompletedAt!.toIso8601String(),
      };

  factory LektionProgress.fromJson(Map<String, dynamic> json) =>
      LektionProgress(
        lektionId: json['lektion_id'] as String,
        levelId: json['level_id'] as String? ?? 'A1.1',
        modulId: json['modul_id'] as String? ?? '',
        status: LektionStatus.values.byName(
          json['status'] as String? ?? 'available',
        ),
        sections: [
          for (final s in (json['sections'] as List? ?? const []))
            SectionProgress.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
        secondsSpent: (json['seconds_spent'] as num?)?.toInt() ?? 0,
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        lastActivityAt: json['last_activity_at'] == null
            ? null
            : DateTime.tryParse(json['last_activity_at'] as String),
        firstCompletedAt: json['first_completed_at'] == null
            ? null
            : DateTime.tryParse(json['first_completed_at'] as String),
      );
}

/// Account-wide totals.
@immutable
class LearnerStats {
  const LearnerStats({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDay,
    this.xpToday = 0,
    this.dailyGoalMinutes = 20,
  });

  final int totalXp;
  final int currentStreak;
  final int longestStreak;

  /// Date only, in the device's local zone. Server-side evaluation in the
  /// user's stored timezone is the eventual source of truth.
  final DateTime? lastActiveDay;

  final int xpToday;
  final int dailyGoalMinutes;

  LearnerStats copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDay,
    int? xpToday,
    int? dailyGoalMinutes,
  }) =>
      LearnerStats(
        totalXp: totalXp ?? this.totalXp,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastActiveDay: lastActiveDay ?? this.lastActiveDay,
        xpToday: xpToday ?? this.xpToday,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      );

  Map<String, dynamic> toJson() => {
        'total_xp': totalXp,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        if (lastActiveDay != null)
          'last_active_day': lastActiveDay!.toIso8601String(),
        'xp_today': xpToday,
        'daily_goal_minutes': dailyGoalMinutes,
      };

  factory LearnerStats.fromJson(Map<String, dynamic> json) => LearnerStats(
        totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
        currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
        lastActiveDay: json['last_active_day'] == null
            ? null
            : DateTime.tryParse(json['last_active_day'] as String),
        xpToday: (json['xp_today'] as num?)?.toInt() ?? 0,
        dailyGoalMinutes:
            (json['daily_goal_minutes'] as num?)?.toInt() ?? 20,
      );
}
