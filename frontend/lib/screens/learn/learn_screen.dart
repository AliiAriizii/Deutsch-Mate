import 'package:flutter/material.dart';

import '../../core/progress/lektion_plan.dart';
import '../../core/progress/progress_models.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/lektion_spine.dart';
import '../../widgets/primitives.dart';
import '../../widgets/progress_scope.dart';
import 'lesson_detail_screen.dart';

/// The Lektion path.
///
/// Every state here now comes from real progress: what is finished, what is
/// open, what is locked behind the Lektion before it. The card at the top says
/// exactly which section to do next, so the answer to "how do I carry on" is
/// never more than one tap away.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final plans = store.plans;
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسیر درس‌ها'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: context.colors.hairline, height: 1),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          spacing.lg,
          spacing.gutter,
          spacing.xxxl,
        ),
        // One extra row at the top for the "continue" card.
        itemCount: plans.length + 1,
        itemBuilder: (context, row) {
          if (row == 0) return const _ContinueCard();

          final index = row - 1;
          final plan = plans[index];
          final status = store.statusFor(plan);
          final opensModul = index % LektionPlan.lektionenPerModul == 0;
          final modulNumber = (index ~/ LektionPlan.lektionenPerModul) + 1;
          final progress = store.progressFor(plan);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (opensModul) ...[
                if (index != 0) SizedBox(height: spacing.lg),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: LektionSpine.modulNodeSize + spacing.md,
                    bottom: spacing.sm,
                  ),
                  child: Row(
                    children: [
                      PlateLabel('Modul $modulNumber'),
                      SizedBox(width: spacing.sm),
                      Expanded(child: Divider(color: context.colors.hairline)),
                    ],
                  ),
                ),
              ],
              SpineRow(
                spine: LektionSpine(
                  state: switch (status) {
                    LektionStatus.completed => SpineState.completed,
                    LektionStatus.inProgress => SpineState.current,
                    LektionStatus.available =>
                      store.currentLektion?.lektionId == plan.lektionId
                          ? SpineState.current
                          : SpineState.available,
                    LektionStatus.locked => SpineState.locked,
                  },
                  isFirst: index == 0,
                  isLast: index == plans.length - 1,
                  opensModul: opensModul,
                  label: '${index + 1}',
                ),
                child: _LektionCard(
                  plan: plan,
                  status: status,
                  doneSections: progress.completedSectionCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The single most useful thing on this screen: what to do next, and a way
/// straight into it.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final spacing = context.spacing;
    final next = store.nextStep;

    if (next == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing.xl),
        child: AppCard(
          borderColor: context.colors.success.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlateLabel('A1.1', color: context.colors.success),
              SizedBox(height: spacing.xs),
              Text('همه درس‌ها تمام شد', style: context.texts.titleMedium),
              SizedBox(height: spacing.xs),
              Text(
                'می‌توانی در بخش تمرین مرور کنی تا سطح بعد اضافه شود.',
                style: context.texts.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xl),
      child: AppCard(
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
            const PlateLabel('ادامه بده'),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${store.completedLektionen} از ${store.plans.length} درس',
                    style: context.texts.labelSmall,
                  ),
                ),
                Text(
                  '${(store.courseFraction * 100).round()}%',
                  style: AppTypography.monoStyle(
                    color: context.colors.accentSoft,
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            AppProgressBar(value: store.courseFraction),
          ],
        ),
      ),
    );
  }
}

class _LektionCard extends StatelessWidget {
  const _LektionCard({
    required this.plan,
    required this.status,
    required this.doneSections,
  });

  final LektionPlan plan;
  final LektionStatus status;
  final int doneSections;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final locked = status == LektionStatus.locked;
    final store = ProgressScope.of(context);
    final isCurrent = store.currentLektion?.lektionId == plan.lektionId;

    return AppCard(
      onTap: locked
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonDetailScreen(plan: plan),
                ),
              ),
      padding: EdgeInsets.all(spacing.lg),
      borderColor: isCurrent ? colors.accent : colors.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: context.texts.titleMedium?.copyWith(
                    color: locked ? colors.textTertiary : colors.textPrimary,
                  ),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                size: 18,
                color: colors.textTertiary,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(plan.topic, style: context.texts.bodySmall),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Text(
                '$doneSections/${plan.stepCount} بخش',
                style: AppTypography.monoStyle(
                  color: colors.textTertiary,
                  size: 11,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  switch (status) {
                    LektionStatus.completed => 'تمام شد',
                    LektionStatus.inProgress => 'در جریان',
                    LektionStatus.available => 'آماده شروع',
                    LektionStatus.locked => 'درس قبلی را تمام کن',
                  },
                  style: context.texts.labelSmall?.copyWith(
                    color: switch (status) {
                      LektionStatus.completed => colors.success,
                      LektionStatus.inProgress ||
                      LektionStatus.available =>
                        colors.accentSoft,
                      LektionStatus.locked => colors.textTertiary,
                    },
                    fontWeight:
                        status == LektionStatus.locked ? null : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
