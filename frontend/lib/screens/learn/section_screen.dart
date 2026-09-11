import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../core/progress/lektion_plan.dart';
import '../../core/progress/progress_models.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/progress_scope.dart';
import 'lesson_detail_screen.dart';

/// One section of a Lektion, with an explicit way to finish it.
///
/// The missing piece in the old app: material was displayed but never
/// concluded, so nothing could ever be marked done and no XP could be earned.
/// Here the content ends in a single action that completes the section, awards
/// its XP, and returns to the Lektion with the step ticked.
class SectionScreen extends StatelessWidget {
  const SectionScreen({super.key, required this.plan, required this.section});

  final LektionPlan plan;
  final SectionKind section;

  Map<String, dynamic> get _lesson => AppData.lessons[plan.index];

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final spacing = context.spacing;
    final alreadyDone = store.progressFor(plan).isSectionDone(section);

    return Scaffold(
      appBar: AppBar(title: Text('${plan.title} · ${section.persian}')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.gutter,
          spacing.sm,
          spacing.gutter,
          spacing.xxxl,
        ),
        children: [
          PlateLabel(section.german),
          SizedBox(height: spacing.sm),
          Text(section.persian, style: context.texts.displaySmall),
          SizedBox(height: spacing.xs),
          Text(_intro, style: context.texts.bodySmall),
          SizedBox(height: spacing.xl),

          ..._content(context),

          SizedBox(height: spacing.xl),
          _FinishButton(
            plan: plan,
            section: section,
            alreadyDone: alreadyDone,
          ),
        ],
      ),
    );
  }

  String get _intro => switch (section) {
        SectionKind.wortschatz =>
          'واژه‌ها را بخوان و تلفظشان را گوش کن. رنگ هر آرتیکل جنسیت اسم را نشان می‌دهد.',
        SectionKind.grammatik =>
          'ساختار تازه این درس. آن را بخوان و با جمله‌های بخش بعد تطبیق بده.',
        SectionKind.redemittel =>
          'جمله‌های کاربردی این درس. هرکدام را گوش کن و بلند تکرار کن.',
        _ => '',
      };

  List<Widget> _content(BuildContext context) {
    switch (section) {
      case SectionKind.wortschatz:
        final words = (_lesson['words'] as List?) ?? const [];
        return [
          for (final w in words)
            VocabRow(
              entry: (w['word'] ?? '').toString(),
              translation: (w['translation'] ?? '').toString(),
            ),
        ];

      case SectionKind.grammatik:
        return [
          AppCard(
            background: context.colors.surface,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                plan.grammar,
                style: AppTypography.monoStyle(
                  color: context.colors.textPrimary,
                  size: 13,
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ];

      case SectionKind.redemittel:
        final sentences = (_lesson['sentences'] as List?) ?? const [];
        return [
          for (final s in sentences)
            SentenceRow(
              german: (s['de'] ?? '').toString(),
              persian: (s['fa'] ?? '').toString(),
            ),
        ];

      default:
        return const [
          EmptyState(
            title: 'این بخش هنوز محتوا ندارد',
            action: 'با تکمیل محتوای دوره اضافه می‌شود.',
          ),
        ];
    }
  }
}

class _FinishButton extends StatefulWidget {
  const _FinishButton({
    required this.plan,
    required this.section,
    required this.alreadyDone,
  });

  final LektionPlan plan;
  final SectionKind section;
  final bool alreadyDone;

  @override
  State<_FinishButton> createState() => _FinishButtonState();
}

class _FinishButtonState extends State<_FinishButton> {
  bool _busy = false;

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);

    final store = ProgressScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final earned = await store.completeSection(
      plan: widget.plan,
      section: widget.section,
      total: widget.plan.itemsIn(widget.section),
      correct: widget.plan.itemsIn(widget.section),
    );

    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            earned > 0
                ? '${widget.section.persian} تمام شد · $earned XP'
                : '${widget.section.persian} تمام شد',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alreadyDone) {
      return AccentEdgeBox(
        tint: context.colors.success,
        child: Row(
          children: [
            Icon(Icons.check, size: 18, color: context.colors.success),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: Text(
                'این بخش را قبلاً تمام کرده‌ای',
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton(
      onPressed: _busy ? null : _finish,
      child: _busy
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.textTertiary,
              ),
            )
          : const Text('این بخش را تمام کردم'),
    );
  }
}
