import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/lektion_spine.dart';
import '../../widgets/primitives.dart';
import 'lesson_detail_screen.dart';

/// The Lektion path.
///
/// Replaces the flat list with the structure the course actually has: 12
/// Lektionen in 4 Module of 3, threaded on the spine. A Lektion that opens a
/// Modul gets a wider node and a Modul header, so the syllabus is readable
/// without opening anything.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  /// Placeholder position until progress sync lands.
  static const _completedCount = 4;

  static const _lektionenPerModul = 3;

  @override
  Widget build(BuildContext context) {
    final lessons = AppData.lessons;
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
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          final opensModul = index % _lektionenPerModul == 0;
          final modulNumber = (index ~/ _lektionenPerModul) + 1;

          final state = switch (index) {
            _ when index < _completedCount => SpineState.completed,
            _completedCount => SpineState.current,
            _ => SpineState.available,
          };

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
                      Expanded(
                        child: Divider(color: context.colors.hairline),
                      ),
                    ],
                  ),
                ),
              ],
              SpineRow(
                spine: LektionSpine(
                  state: state,
                  isFirst: index == 0,
                  isLast: index == lessons.length - 1,
                  opensModul: opensModul,
                  label: '${index + 1}',
                ),
                child: _LektionCard(
                  lesson: lesson,
                  state: state,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonDetailScreen(lessonData: lesson),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LektionCard extends StatelessWidget {
  const _LektionCard({
    required this.lesson,
    required this.state,
    required this.onTap,
  });

  final Map<String, dynamic> lesson;
  final SpineState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final isCurrent = state == SpineState.current;
    final wordCount = (lesson['words'] as List?)?.length ?? 0;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(spacing.lg),
      // The current Lektion is the only card with a coloured edge, which is
      // what makes "where am I" answerable at a glance.
      borderColor: isCurrent ? colors.accent : colors.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson['name']?.toString() ?? '',
                  style: context.texts.titleMedium,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.textTertiary,
                // Mirrors with the layout, so it always points "forward".
                textDirection: Directionality.of(context),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            lesson['topic']?.toString() ?? '',
            style: context.texts.bodySmall,
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Text(
                '$wordCount واژه',
                style: AppTypography.monoStyle(
                  color: colors.textTertiary,
                  size: 11,
                ),
              ),
              SizedBox(width: spacing.md),
              if (state == SpineState.completed)
                Text('تمام شد', style: context.texts.labelSmall)
              else if (isCurrent)
                Text(
                  'ادامه بده',
                  style: context.texts.labelSmall?.copyWith(
                    color: colors.accentSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
