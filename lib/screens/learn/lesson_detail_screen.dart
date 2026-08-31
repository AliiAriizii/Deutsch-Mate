import 'package:flutter/material.dart';

import '../../core/german.dart';
import '../../core/progress/lektion_plan.dart';
import '../../core/progress/progress_models.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/gender_chip.dart';
import '../../widgets/primitives.dart';
import '../../widgets/progress_scope.dart';
import '../../widgets/speak_button.dart';
import 'section_screen.dart';

/// One Lektion, as a list of steps.
///
/// This screen answers "what do I do here". It used to be a wall of vocabulary
/// with no beginning, no end and no way to finish, which is why progression was
/// invisible. Now a Lektion *is* its sections: each one opens, is worked
/// through, and is ticked off; the Lektion completes when they all are.
class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key, required this.plan});

  final LektionPlan plan;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final spacing = context.spacing;
    final progress = store.progressFor(plan);
    final done = progress.completedSectionCount;
    final total = plan.stepCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: [SpeakButton(text: plan.name, size: 22)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          spacing.sm,
          spacing.gutter,
          spacing.xxxl,
        ),
        children: [
          Text(
            plan.name,
            style: context.texts.displaySmall,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
          ),
          SizedBox(height: spacing.sm),
          Text(plan.topic, style: context.texts.bodySmall),
          SizedBox(height: spacing.lg),

          // This Lektion's progress, as a figure and not only a bar.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        done == total && total > 0
                            ? 'این درس کامل شد'
                            : 'پیشرفت این درس',
                        style: context.texts.titleSmall,
                      ),
                    ),
                    Text(
                      '$done / $total',
                      style: AppTypography.monoStyle(
                        color: context.colors.accentSoft,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                AppProgressBar(value: total == 0 ? 0 : done / total),
                if (progress.xpEarned > 0) ...[
                  SizedBox(height: spacing.sm),
                  Text(
                    '${progress.xpEarned} XP از این درس',
                    style: context.texts.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'بخش‌های درس', eyebrow: 'مسیر'),
          for (var i = 0; i < plan.steps.length; i++)
            _StepTile(
              plan: plan,
              section: plan.steps[i],
              number: i + 1,
              done: progress.isSectionDone(plan.steps[i]),
              // Steps unlock in order, so there is always exactly one obvious
              // next action rather than several equal-looking choices.
              enabled: i == 0 ||
                  progress.isSectionDone(plan.steps[i - 1]) ||
                  progress.isSectionDone(plan.steps[i]),
            ),

          SizedBox(height: spacing.xl),
          const _NotYetAuthored(),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.plan,
    required this.section,
    required this.number,
    required this.done,
    required this.enabled,
  });

  final LektionPlan plan;
  final SectionKind section;
  final int number;
  final bool done;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final count = plan.itemsIn(section);

    final tint = done
        ? colors.success
        : enabled
            ? colors.accent
            : colors.textTertiary;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: AppCard(
        onTap: enabled
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SectionScreen(plan: plan, section: section),
                  ),
                )
            : null,
        borderColor: done
            ? colors.success.withValues(alpha: 0.45)
            : enabled
                ? colors.accent.withValues(alpha: 0.45)
                : colors.hairline,
        child: Row(
          children: [
            // Step number, or a tick once it is behind you.
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: done ? 1 : 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: tint.withValues(alpha: 0.6)),
              ),
              child: done
                  ? Icon(Icons.check, size: 17, color: colors.scaffold)
                  : Text(
                      '$number',
                      style: AppTypography.monoStyle(
                        color: tint,
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
            ),
            SizedBox(width: spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlateLabel(section.german, color: tint),
                  SizedBox(height: spacing.xxs),
                  Text(section.persian, style: context.texts.titleSmall),
                  SizedBox(height: spacing.xxs),
                  Text(
                    done
                        ? 'انجام شد'
                        : enabled
                            ? '$count مورد · برای شروع بزن'
                            : 'اول بخش قبلی را تمام کن',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
            if (enabled && !done)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.textTertiary,
                textDirection: Directionality.of(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// Names the two sections the content cannot fill yet, rather than quietly
/// shipping a three-step Lektion as though it were the whole thing.
class _NotYetAuthored extends StatelessWidget {
  const _NotYetAuthored();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      background: context.colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlateLabel('در دست تهیه'),
          SizedBox(height: context.spacing.sm),
          Text(
            'بخش‌های Einstieg و Abschluss هنوز محتوا ندارند و با تکمیل محتوای '
            'دوره اضافه می‌شوند.',
            style: context.texts.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A vocabulary row, shared with the section screen.
class VocabRow extends StatelessWidget {
  const VocabRow({
    super.key,
    required this.entry,
    required this.translation,
  });

  final String entry;
  final String translation;

  /// Reserved width for the article chip, so the German column stays flush
  /// whether or not an entry has an article.
  static const articleSlot = 38.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final noun = parseGermanEntry(entry);

    return Container(
      margin: EdgeInsets.only(bottom: spacing.xs),
      padding: EdgeInsetsDirectional.only(
        start: spacing.md,
        end: spacing.xs,
        top: spacing.sm,
        bottom: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: context.radii.controlBorder,
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: articleSlot,
            child: noun.hasArticle
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: GenderChip(article: noun.article!, compact: true),
                  )
                : null,
          ),
          SizedBox(width: spacing.sm),
          Text(
            noun.word,
            style: context.texts.bodyLarge,
            textDirection: TextDirection.ltr,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              translation,
              style: context.texts.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SpeakButton(text: entry, size: 18),
        ],
      ),
    );
  }
}

/// An example sentence with its translation.
class SentenceRow extends StatelessWidget {
  const SentenceRow({
    super.key,
    required this.german,
    required this.persian,
  });

  final String german;
  final String persian;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      margin: EdgeInsets.only(bottom: spacing.sm),
      child: AccentEdgeBox(
        tint: colors.accent,
        background: colors.card,
        barWidth: 2,
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    german,
                    style: context.texts.bodyLarge,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                  ),
                  SizedBox(height: spacing.xxs),
                  Text(persian, style: context.texts.bodySmall),
                ],
              ),
            ),
            SpeakButton(text: german),
          ],
        ),
      ),
    );
  }
}
