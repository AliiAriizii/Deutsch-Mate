import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../core/german.dart';
import '../../widgets/progress_scope.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Progress.
///
/// The percentages are placeholders until sync lands, but the gender breakdown
/// is computed from the real word list - it is the one figure on this screen
/// that is not invented.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final store = ProgressScope.of(context);
    final counts = _genderCounts();
    final total = counts.values.fold(0, (a, b) => a + b);
    final level = store.levelProgress;

    return Scaffold(
      appBar: AppBar(title: const Text('پیشرفت')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          0,
          spacing.gutter,
          spacing.xxxl,
        ),
        children: [
          SectionHeader(title: 'سطح فعلی', eyebrow: 'Menschen A1.1'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${(store.courseFraction * 100).round()}',
                      style: AppTypography.monoStyle(
                        color: context.colors.accentSoft,
                        size: 32,
                        weight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    Text('%', style: context.texts.titleMedium),
                    const Spacer(),
                    Text(
                      '${store.completedLektionen} از ${store.plans.length} درس',
                      style: context.texts.labelSmall,
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                AppProgressBar(value: store.courseFraction),
              ],
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'توزیع جنسیت اسم‌ها', eyebrow: 'Wortschatz'),
          AppCard(
            child: Column(
              children: [
                _GenderBar(
                  article: 'der',
                  count: counts['der'] ?? 0,
                  total: total,
                ),
                SizedBox(height: spacing.md),
                _GenderBar(
                  article: 'die',
                  count: counts['die'] ?? 0,
                  total: total,
                ),
                SizedBox(height: spacing.md),
                _GenderBar(
                  article: 'das',
                  count: counts['das'] ?? 0,
                  total: total,
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'XP و سطح', eyebrow: 'تلاش'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'سطح ${level.level}',
                        style: context.texts.titleSmall,
                      ),
                    ),
                    Text(
                      '${store.stats.totalXp} XP',
                      style: AppTypography.monoStyle(
                        color: context.colors.accentSoft,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                AppProgressBar(value: level.fraction),
                SizedBox(height: spacing.sm),
                Text(
                  '${level.into} از ${level.needed} XP تا سطح بعد',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'مهارت‌ها', eyebrow: 'هنوز اندازه‌گیری نمی‌شود'),
          AppCard(
            background: context.colors.surface,
            child: Text(
              'تفکیک مهارت‌ها به سابقه پاسخ‌های هر واژه نیاز دارد که هنوز ذخیره '
              'نمی‌شود. تا آن زمان عددی نشان نمی‌دهیم؛ اعداد قبلی ثابت و ساختگی بودند.',
              style: context.texts.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, int> _genderCounts() {
    final counts = <String, int>{'der': 0, 'die': 0, 'das': 0};
    final entries = AppData.lessons
        .expand((l) => (l['words'] as List? ?? const []))
        .map((w) => (w['word'] ?? '').toString());
    for (final noun in nounsWithArticles(entries)) {
      counts[noun.article!] = (counts[noun.article!] ?? 0) + 1;
    }
    return counts;
  }
}

/// One gender's share of the word list, in that gender's colour.
class _GenderBar extends StatelessWidget {
  const _GenderBar({
    required this.article,
    required this.count,
    required this.total,
  });

  final String article;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.forArticle(article);
    final ratio = total == 0 ? 0.0 : count / total;

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            article,
            style: AppTypography.monoStyle(color: tint, size: 13),
          ),
        ),
        SizedBox(width: context.spacing.md),
        Expanded(child: AppProgressBar(value: ratio, tint: tint, height: 6)),
        SizedBox(width: context.spacing.md),
        SizedBox(
          width: 30,
          child: Text(
            '$count',
            style: AppTypography.monoStyle(
              color: context.colors.textSecondary,
              size: 13,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
