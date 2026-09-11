import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deutsch_mate/core/progress/lektion_plan.dart';
import 'package:deutsch_mate/core/progress/progress_models.dart';
import 'package:deutsch_mate/core/progress/progress_store.dart';
import 'package:deutsch_mate/core/progress/xp_rules.dart';

void main() {
  group('XP rules', () {
    test('a wrong answer earns nothing', () {
      expect(
        XpRules.award(
          exerciseClass: ExerciseClass.production,
          outcome: AttemptOutcome.incorrect,
          streakDays: 30,
          earnedToday: 0,
          dailyGoalXp: 60,
        ),
        0,
      );
    });

    test('harder exercise classes are worth more', () {
      int award(ExerciseClass c) => XpRules.award(
            exerciseClass: c,
            outcome: AttemptOutcome.firstCorrect,
            streakDays: 0,
            earnedToday: 0,
            dailyGoalXp: 60,
          );
      expect(award(ExerciseClass.recognition), lessThan(award(ExerciseClass.recall)));
      expect(award(ExerciseClass.recall), lessThan(award(ExerciseClass.listening)));
      expect(award(ExerciseClass.listening), lessThan(award(ExerciseClass.production)));
      expect(award(ExerciseClass.production), lessThan(award(ExerciseClass.free)));
    });

    test('practising ahead is worth less than a due review', () {
      expect(
        XpRules.outcomeMultiplier(AttemptOutcome.aheadOfSchedule),
        lessThan(XpRules.outcomeMultiplier(AttemptOutcome.dueReview)),
      );
      expect(
        XpRules.outcomeMultiplier(AttemptOutcome.dueReview),
        lessThan(XpRules.outcomeMultiplier(AttemptOutcome.firstCorrect)),
      );
    });

    test('diminishing returns apply last, so a streak cannot escape the cap',
        () {
      // Deep into the day, even a maxed streak earns the reduced rate.
      final fresh = XpRules.award(
        exerciseClass: ExerciseClass.free,
        outcome: AttemptOutcome.firstCorrect,
        streakDays: 30,
        earnedToday: 0,
        dailyGoalXp: 60,
      );
      final grinding = XpRules.award(
        exerciseClass: ExerciseClass.free,
        outcome: AttemptOutcome.firstCorrect,
        streakDays: 30,
        earnedToday: 500,
        dailyGoalXp: 60,
      );
      expect(grinding, lessThan(fresh));
    });

    test('an award that earned something never rounds away to zero', () {
      final tiny = XpRules.award(
        exerciseClass: ExerciseClass.recognition,
        outcome: AttemptOutcome.aheadOfSchedule,
        streakDays: 0,
        earnedToday: 10000,
        dailyGoalXp: 60,
      );
      expect(tiny, greaterThanOrEqualTo(1));
    });

    test('the level curve is the formula, not the illustrative table', () {
      // 80 * n^1.45. The brief's table drifts at 5, 25 and 50.
      expect(XpRules.xpForLevel(1), 0);
      expect(XpRules.xpForLevel(2), 219);
      expect(XpRules.xpForLevel(10), 2255);
    });

    test('levelForXp and xpForLevel agree at every boundary', () {
      for (var level = 1; level <= 40; level++) {
        final floor = XpRules.xpForLevel(level);
        expect(XpRules.levelForXp(floor), level, reason: 'at floor of $level');
        if (level > 1) {
          expect(
            XpRules.levelForXp(floor - 1),
            level - 1,
            reason: 'one XP below the floor of $level',
          );
        }
      }
    });

    test('level progress reports the raw figures, not only a fraction', () {
      final p = XpRules.levelProgress(300);
      expect(p.level, 2);
      expect(p.into, 300 - XpRules.xpForLevel(2));
      expect(p.needed, XpRules.xpForLevel(3) - XpRules.xpForLevel(2));
      expect(p.fraction, inInclusiveRange(0, 1));
    });
  });

  group('progress store', () {
    late List<LektionPlan> plans;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      plans = buildLektionPlans();
    });

    Future<ProgressStore> newStore() async => ProgressStore.load(
          plans: plans,
          prefs: await SharedPreferences.getInstance(),
        );

    test('a fresh learner starts at zero, not at a hardcoded 4 of 12', () async {
      final store = await newStore();
      expect(store.completedLektionen, 0);
      expect(store.courseFraction, 0);
      expect(store.stats.totalXp, 0);
      expect(store.level, 1);
    });

    test('only the first Lektion is open at the start', () async {
      final store = await newStore();
      expect(store.isUnlocked(plans.first), isTrue);
      expect(store.isUnlocked(plans[1]), isFalse);
      expect(store.statusFor(plans[1]), LektionStatus.locked);
    });

    test('nextStep names the exact section to do, from a cold start', () async {
      final store = await newStore();
      final next = store.nextStep;

      expect(next, isNotNull);
      expect(next!.plan.lektionId, plans.first.lektionId);
      expect(next.section, plans.first.steps.first);
    });

    test('completing a section advances nextStep and awards XP', () async {
      final store = await newStore();
      final plan = plans.first;

      final earned = await store.completeSection(
        plan: plan,
        section: plan.steps.first,
      );

      expect(earned, greaterThan(0));
      expect(store.stats.totalXp, earned);
      expect(store.progressFor(plan).isSectionDone(plan.steps.first), isTrue);
      expect(store.nextStep!.section, plan.steps[1]);
      expect(store.statusFor(plan), LektionStatus.inProgress);
    });

    test('finishing every section completes the Lektion and unlocks the next',
        () async {
      final store = await newStore();
      final plan = plans.first;

      for (final section in plan.steps) {
        await store.completeSection(plan: plan, section: section);
      }

      expect(store.statusFor(plan), LektionStatus.completed);
      expect(store.completedLektionen, 1);
      expect(store.isUnlocked(plans[1]), isTrue);
      expect(store.nextStep!.plan.lektionId, plans[1].lektionId);
    });

    test('completing the same section twice awards nothing extra', () async {
      final store = await newStore();
      final plan = plans.first;
      final first = await store.completeSection(
        plan: plan,
        section: plan.steps.first,
      );
      final second = await store.completeSection(
        plan: plan,
        section: plan.steps.first,
      );

      expect(first, greaterThan(0));
      expect(second, 0, reason: 'grinding one section must not farm XP');
      expect(store.stats.totalXp, first);
    });

    test('progress survives a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = await ProgressStore.load(plans: plans, prefs: prefs);
      await first.completeSection(
        plan: plans.first,
        section: plans.first.steps.first,
      );
      final xp = first.stats.totalXp;

      final reopened = await ProgressStore.load(plans: plans, prefs: prefs);
      expect(reopened.stats.totalXp, xp);
      expect(
        reopened.progressFor(plans.first).isSectionDone(plans.first.steps.first),
        isTrue,
      );
    });

    test('a corrupt payload resets instead of crashing every launch', () async {
      SharedPreferences.setMockInitialValues({
        'learner_progress_v1': '{not json at all',
      });
      final store = await ProgressStore.load(
        plans: plans,
        prefs: await SharedPreferences.getInstance(),
      );
      expect(store.stats.totalXp, 0);
      expect(store.completedLektionen, 0);
    });

    test('the first activity starts a one-day streak', () async {
      final store = await newStore();
      expect(store.stats.currentStreak, 0);

      await store.completeSection(
        plan: plans.first,
        section: plans.first.steps.first,
      );
      expect(store.stats.currentStreak, 1);
      expect(store.stats.longestStreak, 1);
    });

    test('drill attempts earn XP, and wrong ones do not', () async {
      final store = await newStore();

      final wrong = await store.recordDrillAttempt(
        exerciseClass: ExerciseClass.recognition,
        correct: false,
      );
      expect(wrong, 0);
      expect(store.stats.totalXp, 0);

      final right = await store.recordDrillAttempt(
        exerciseClass: ExerciseClass.recognition,
        correct: true,
      );
      expect(right, greaterThan(0));
      expect(store.stats.totalXp, right);
    });

    test('reset clears everything', () async {
      final store = await newStore();
      await store.completeSection(
        plan: plans.first,
        section: plans.first.steps.first,
      );
      await store.reset();

      expect(store.stats.totalXp, 0);
      expect(store.completedLektionen, 0);
      expect(store.nextStep!.plan.lektionId, plans.first.lektionId);
    });
  });

  group('lektion plans', () {
    test('every Lektion has steps derived from the content it actually has',
        () {
      final plans = buildLektionPlans();
      expect(plans, hasLength(12));

      for (final plan in plans) {
        expect(plan.steps, isNotEmpty, reason: '${plan.title} has no steps');
        // Only sections with content become steps: nothing offers a dead end.
        for (final step in plan.steps) {
          expect(
            plan.itemsIn(step),
            greaterThan(0),
            reason: '${plan.title}/${step.name} is a step with no content',
          );
        }
      }
    });

    test('ids are unique and grouped three to a Modul', () {
      final plans = buildLektionPlans();
      final ids = plans.map((p) => p.lektionId).toSet();
      expect(ids, hasLength(plans.length));

      expect(plans[0].modulId, plans[1].modulId);
      expect(plans[1].modulId, plans[2].modulId);
      expect(plans[3].modulId, isNot(plans[2].modulId));
    });
  });
}
