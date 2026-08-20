import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../core/german.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/gender_chip.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quiz_widgets.dart';
import '../../widgets/speak_button.dart';
import 'lesson_filter.dart';

/// Review cards.
///
/// Still a single-session queue rather than real Leitner boxes with intervals -
/// that needs the local database. What is real here is the review accent
/// (violet), which marks this as a different mode from learning new material.
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  bool _revealed = false;
  int _sessionSize = 0;
  int _known = 0;
  String _lessonFilter = kAllLessons;
  List<_Card> _cards = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final cards = <_Card>[];
    for (final lesson in AppData.lessons) {
      final title = lesson['title']?.toString() ?? '';
      if (_lessonFilter != kAllLessons && title != _lessonFilter) continue;

      for (final w in (lesson['words'] as List? ?? const [])) {
        cards.add(
          _Card(
            entry: (w['word'] ?? '').toString(),
            translation: (w['translation'] ?? '').toString(),
            lesson: title,
          ),
        );
      }
    }
    cards.shuffle();

    setState(() {
      _cards = cards;
      _sessionSize = cards.length;
      _known = 0;
      _revealed = false;
    });
  }

  void _again() {
    if (_cards.isEmpty) return;
    setState(() {
      _revealed = false;
      final card = _cards.removeAt(0);
      _cards.add(card); // back of the queue
    });
  }

  void _got() {
    if (_cards.isEmpty) return;
    setState(() {
      _revealed = false;
      _known++;
      _cards.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final done = _sessionSize - _cards.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('کارت‌های مرور'),
        actions: [ScoreReadout(value: _known, unit: 'بلد')],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.gutter),
          child: Column(
            children: [
              LessonFilter(
                value: _lessonFilter,
                onChanged: (v) {
                  _lessonFilter = v;
                  _load();
                },
              ),
              SizedBox(height: spacing.md),
              if (_sessionSize > 0)
                AppProgressBar(
                  value: _sessionSize == 0 ? 0 : done / _sessionSize,
                  tint: colors.review,
                  height: 4,
                ),
              SizedBox(height: spacing.xl),
              Expanded(
                child: _cards.isEmpty
                    ? _completion(context)
                    : _card(context, _cards.first),
              ),
              if (_cards.isNotEmpty) _actions(context),
              SizedBox(height: spacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _Card card) {
    final colors = context.colors;
    final spacing = context.spacing;
    final noun = parseGermanEntry(card.entry);

    return Center(
      child: AppCard(
        onTap: () => setState(() => _revealed = !_revealed),
        // Review mode owns the violet edge.
        borderColor: colors.review.withValues(alpha: 0.45),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.xl,
          vertical: spacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlateLabel(card.lesson, color: colors.review),
            SizedBox(height: spacing.xl),
            if (noun.hasArticle && !_revealed) ...[
              GenderChip(article: noun.article!),
              SizedBox(height: spacing.md),
            ],
            AnimatedSwitcher(
              duration: context.motion.resolve(context, context.motion.quick),
              child: Text(
                _revealed ? card.translation : noun.word,
                key: ValueKey(_revealed),
                style: context.texts.displaySmall,
                textAlign: TextAlign.center,
                textDirection:
                    _revealed ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
            SizedBox(height: spacing.lg),
            if (!_revealed)
              SpeakButton(text: card.entry, size: 22)
            else
              Text(
                noun.word,
                style: AppTypography.monoStyle(
                  color: colors.textTertiary,
                  size: 13,
                ),
              ),
            SizedBox(height: spacing.md),
            Text(
              _revealed ? 'برای برگشت بزن' : 'برای دیدن معنی بزن',
              style: context.texts.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final spacing = context.spacing;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _again,
            child: const Text('باز هم ببینم'),
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: FilledButton(onPressed: _got, child: const Text('بلد بودم')),
        ),
      ],
    );
  }

  Widget _completion(BuildContext context) {
    final spacing = context.spacing;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_known / $_sessionSize', style: context.texts.displaySmall),
          SizedBox(height: spacing.sm),
          Text('این دور تمام شد', style: context.texts.titleSmall),
          SizedBox(height: spacing.xs),
          Text(
            'کارت‌ها را دوباره بچین یا درس دیگری را مرور کن.',
            style: context.texts.bodySmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.xl),
          FilledButton(onPressed: _load, child: const Text('دور تازه')),
        ],
      ),
    );
  }
}

class _Card {
  const _Card({
    required this.entry,
    required this.translation,
    required this.lesson,
  });

  final String entry;
  final String translation;
  final String lesson;
}
