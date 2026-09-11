import 'package:flutter/material.dart';

import '../../core/progress/progress_models.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/progress_scope.dart';
import '../learn/lesson_detail_screen.dart';

/// Home.
///
/// Every figure on this screen is now computed from what the learner has
/// actually done. It previously showed a hardcoded 4 completed Lektionen and a
/// fixed 33%, which is why progress looked frozen no matter what you did.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final spacing = context.spacing;
    final stats = store.stats;
    final level = store.levelProgress;

    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Deutsch', style: context.texts.headlineSmall),
              TextSpan(
                text: 'Mate',
                style: context.texts.headlineSmall?.copyWith(
                  color: context.colors.accentSoft,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          0,
          spacing.gutter,
          spacing.xxxl,
        ),
        children: [
          Text('Guten Tag', style: context.texts.displaySmall),
          SizedBox(height: spacing.xs),
          Text(
            stats.totalXp == 0
                ? 'هنوز شروع نکرده‌ای. اولین بخش منتظر توست.'
                : 'تا حالا ${stats.totalXp} XP جمع کرده‌ای.',
            style: context.texts.bodySmall,
          ),
          SizedBox(height: spacing.xl),

          const _NextStepCard(),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'امروز', eyebrow: 'هدف روزانه'),
          const _TodayCard(),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'سطح', eyebrow: 'XP'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'سطح ',
                      style: context.texts.titleSmall,
                    ),
                    Text(
                      '${level.level}',
                      style: AppTypography.monoStyle(
                        color: context.colors.accentSoft,
                        size: 28,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    // The raw figures, not just a bar: a bar alone hides how
                    // much is actually left.
                    Text(
                      '${level.into} / ${level.needed} XP',
                      style: AppTypography.monoStyle(
                        color: context.colors.textSecondary,
                        size: 13,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                AppProgressBar(value: level.fraction),
                SizedBox(height: spacing.sm),
                Text(
                  'برای سطح ${level.level + 1} به '
                  '${(level.needed - level.into).clamp(0, 1 << 31)} XP دیگر نیاز داری',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'یک نگاه', eyebrow: 'وضعیت'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${store.completedLektionen}',
                  label: 'درس تمام‌شده',
                  tint: context.colors.accentSoft,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: StatTile(
                  value: '${stats.currentStreak}',
                  label: 'روز پیاپی',
                  tint: stats.currentStreak > 0
                      ? context.colors.warning
                      : null,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.totalXp}',
                  label: 'مجموع XP',
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: StatTile(
                  value: '${stats.longestStreak}',
                  label: 'بلندترین رکورد',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What to do next, with a way straight into it.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard();

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final spacing = context.spacing;
    final next = store.nextStep;

    if (next == null) {
      return AppCard(
        borderColor: context.colors.success.withValues(alpha: 0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlateLabel('A1.1', color: context.colors.success),
            SizedBox(height: spacing.xs),
            Text('سطح A1.1 تمام شد', style: context.texts.titleMedium),
            SizedBox(height: spacing.xs),
            Text(
              'در بخش تمرین مرور کن تا سطح بعد اضافه شود.',
              style: context.texts.bodySmall,
            ),
          ],
        ),
      );
    }

    return AppCard(
      borderColor: context.colors.accent,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonDetailScreen(plan: next.plan),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlateLabel('قدم بعدی'),
          SizedBox(height: spacing.xs),
          Text(
            '${next.plan.title} · ${next.section.persian}',
            style: context.texts.titleMedium,
          ),
          SizedBox(height: spacing.xs),
          Text(
            next.plan.name,
            style: context.texts.bodySmall,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
          ),
          SizedBox(height: spacing.md),
          AppProgressBar(value: store.courseFraction),
          SizedBox(height: spacing.sm),
          Text(
            '${store.completedLektionen} از ${store.plans.length} درس · '
            '${(store.courseFraction * 100).round()}%',
            style: context.texts.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Today's goal as a ring plus the numbers behind it.
class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final met = store.dailyGoalMet;
    final tint = met ? colors.success : colors.accent;

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: store.todayFraction,
                    strokeWidth: 5,
                    backgroundColor: colors.inputFill,
                    valueColor: AlwaysStoppedAnimation(tint),
                  ),
                ),
                if (met)
                  Icon(Icons.check, size: 22, color: colors.success)
                else
                  Text(
                    '${(store.todayFraction * 100).round()}',
                    style: AppTypography.monoStyle(
                      color: colors.textSecondary,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  met ? 'هدف امروز انجام شد' : 'هدف امروز',
                  style: context.texts.titleSmall?.copyWith(
                    color: met ? colors.success : colors.textPrimary,
                  ),
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  '${store.stats.xpToday} از ${store.dailyGoalXp} XP',
                  style: context.texts.bodySmall,
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  // Says plainly what keeps a streak alive, instead of only
                  // warning once it is about to break.
                  met
                      ? 'رکوردت حفظ شد'
                      : 'با رسیدن به هدف، روز پیاپی ثبت می‌شود',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
