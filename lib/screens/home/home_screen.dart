import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../core/german.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/gender_chip.dart';
import '../../widgets/primitives.dart';

/// Home.
///
/// The figures here are still placeholders - real values arrive with progress
/// sync. What changed is that they are laid out as a dense readout rather than
/// a gamified dashboard, and the streak no longer shouts.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final lessons = AppData.lessons;

    // Placeholder position until progress is wired.
    const completed = 4;
    final total = lessons.length;
    final ratio = completed / total;

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
            'ادامه از درس ${completed + 1} از $total',
            style: context.texts.bodySmall,
          ),
          SizedBox(height: spacing.xl),

          _CoursePanel(completed: completed, total: total, ratio: ratio),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'یک نگاه', eyebrow: 'وضعیت'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '$completed',
                  label: 'درس تمام‌شده',
                  tint: context.colors.accentSoft,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: StatTile(
                  value: '${_articleCount(lessons)}',
                  label: 'اسم با آرتیکل',
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${_wordCount(lessons)}',
                  label: 'واژه در این سطح',
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: StatTile(
                  value: '${_sentenceCount(lessons)}',
                  label: 'جمله نمونه',
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(title: 'جنسیت اسم‌ها', eyebrow: 'راهنمای رنگ'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رنگ هر آرتیکل در تمام برنامه یکسان است. '
                  'با نگاه‌کردن به رنگ می‌توانی جنسیت اسم را تشخیص بدهی.',
                  style: context.texts.bodySmall,
                ),
                SizedBox(height: spacing.md),
                const GenderLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _wordCount(List<Map<String, dynamic>> lessons) => lessons.fold(
        0,
        (sum, l) => sum + ((l['words'] as List?)?.length ?? 0),
      );

  static int _sentenceCount(List<Map<String, dynamic>> lessons) => lessons.fold(
        0,
        (sum, l) => sum + ((l['sentences'] as List?)?.length ?? 0),
      );

  static int _articleCount(List<Map<String, dynamic>> lessons) {
    final entries = lessons
        .expand((l) => (l['words'] as List? ?? const []))
        .map((w) => (w['word'] ?? '').toString());
    return nounsWithArticles(entries).length;
  }
}

/// The course panel. One saturated element in this view - the progress fill -
/// and everything else steps down to the soft blue or plain text.
class _CoursePanel extends StatelessWidget {
  const _CoursePanel({
    required this.completed,
    required this.total,
    required this.ratio,
  });

  final int completed;
  final int total;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return AppCard(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PlateLabel('Menschen · Kursbuch'),
                    SizedBox(height: spacing.xs),
                    Text('A1.1', style: context.texts.displaySmall),
                  ],
                ),
              ),
              // Percentage in mono so the glyphs do not shift as it changes.
              Text(
                '${(ratio * 100).round()}%',
                style: AppTypography.monoStyle(
                  color: colors.accentSoft,
                  size: 20,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          AppProgressBar(value: ratio),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '4 مدول · 12 درس',
                  style: context.texts.labelSmall,
                ),
              ),
              Text(
                '$completed از $total',
                style: AppTypography.monoStyle(
                  color: colors.textSecondary,
                  size: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
