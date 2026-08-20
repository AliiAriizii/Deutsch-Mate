import 'package:flutter/material.dart';

import '../../core/constants/app_data.dart';
import '../../core/german.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quiz_widgets.dart';
import '../../widgets/speak_button.dart';
import 'lesson_filter.dart';

/// der / die / das drill.
///
/// The three answer buttons carry the gender colours, so the colour a learner
/// picks here is the same colour they saw on the vocabulary row. That is the
/// whole point of colour-coding gender rather than decorating with it.
class ArtikelTrainerScreen extends StatefulWidget {
  const ArtikelTrainerScreen({super.key});

  @override
  State<ArtikelTrainerScreen> createState() => _ArtikelTrainerScreenState();
}

class _ArtikelTrainerScreenState extends State<ArtikelTrainerScreen> {
  static const _articles = ['der', 'die', 'das'];

  int _index = 0;
  int _score = 0;
  String? _picked;
  String _lessonFilter = kAllLessons;
  List<_ArticleItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final items = <_ArticleItem>[];
    for (final lesson in AppData.lessons) {
      final title = lesson['title']?.toString() ?? '';
      if (_lessonFilter != kAllLessons && title != _lessonFilter) continue;

      for (final w in (lesson['words'] as List? ?? const [])) {
        final noun = parseGermanEntry((w['word'] ?? '').toString());
        if (!noun.hasArticle) continue;
        items.add(
          _ArticleItem(
            article: noun.article!,
            noun: noun.word,
            translation: (w['translation'] ?? '').toString(),
            lesson: title,
          ),
        );
      }
    }
    items.shuffle();

    setState(() {
      _items = items;
      _index = 0;
      _picked = null;
    });
  }

  void _pick(String article) {
    if (_picked != null) return;
    final correct = _items[_index].article == article;
    setState(() {
      _picked = article;
      if (correct) _score += 10;
    });
  }

  void _next() {
    setState(() {
      _picked = null;
      if (_index < _items.length - 1) {
        _index++;
      } else {
        _index = 0;
        _items = List.of(_items)..shuffle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تمرین آرتیکل'),
        actions: [ScoreReadout(value: _score, unit: 'XP')],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.gutter),
          child: _items.isEmpty
              ? const EmptyState(
                  title: 'اسمی با آرتیکل در این درس نیست',
                  action: 'درس دیگری انتخاب کن یا همه درس‌ها را ببین.',
                  icon: Icons.filter_alt_outlined,
                )
              : Column(
                  children: [
                    LessonFilter(
                      value: _lessonFilter,
                      onChanged: (v) {
                        _lessonFilter = v;
                        _load();
                      },
                    ),
                    SizedBox(height: spacing.lg),
                    Expanded(child: _prompt(context)),
                    _answerRow(context),
                    SizedBox(height: spacing.lg),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _prompt(BuildContext context) {
    final item = _items[_index];
    final colors = context.colors;
    final spacing = context.spacing;
    final revealed = _picked != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The word sits on its own surface rather than floating in the middle
        // of an empty screen - it is the object of the exercise, so it should
        // read as an object.
        AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xl,
            vertical: spacing.xxl,
          ),
          borderColor: revealed
              ? colors.forArticle(item.article).withValues(alpha: 0.45)
              : colors.hairline,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlateLabel(item.lesson),
                  SizedBox(width: spacing.sm),
                  Text(
                    '${_index + 1}/${_items.length}',
                    style: AppTypography.monoStyle(
                      color: colors.textTertiary,
                      size: 11,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xl),

              // The blank is where the answer lands, and it takes the gender
              // colour the moment it is revealed.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                textDirection: TextDirection.ltr,
                children: [
                  AnimatedSwitcher(
                    duration:
                        context.motion.resolve(context, context.motion.quick),
                    child: Text(
                      revealed ? item.article : '—',
                      key: ValueKey(revealed),
                      style: AppTypography.monoStyle(
                        color: revealed
                            ? colors.forArticle(item.article)
                            : colors.textTertiary,
                        size: 28,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Text(
                    item.noun,
                    style: context.texts.displaySmall,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Text(item.translation, style: context.texts.bodySmall),
            ],
          ),
        ),

        if (revealed) ...[
          SizedBox(height: spacing.xl),
          FeedbackBanner(
            kind: _picked == item.article
                ? FeedbackKind.correct
                : FeedbackKind.wrong,
            headline: _picked == item.article ? 'Richtig' : 'Falsch',
            detail: '${item.article} ${item.noun}',
            trailing: SpeakButton(text: '${item.article} ${item.noun}'),
          ),
          SizedBox(height: spacing.lg),
          FilledButton(onPressed: _next, child: const Text('واژه بعدی')),
        ],
      ],
    );
  }

  Widget _answerRow(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final item = _items[_index];

    return Row(
      children: [
        for (final article in _articles) ...[
          if (article != _articles.first) SizedBox(width: spacing.sm),
          Expanded(
            child: _ArticleButton(
              article: article,
              tint: colors.forArticle(article),
              // After an answer, the correct option stays lit and the wrong
              // pick is marked - both are information the learner needs.
              state: switch (_picked) {
                null => _ArticleButtonState.idle,
                _ when article == item.article => _ArticleButtonState.correct,
                _ when article == _picked => _ArticleButtonState.wrong,
                _ => _ArticleButtonState.dimmed,
              },
              onTap: _picked == null ? () => _pick(article) : null,
            ),
          ),
        ],
      ],
    );
  }
}

enum _ArticleButtonState { idle, correct, wrong, dimmed }

class _ArticleButton extends StatelessWidget {
  const _ArticleButton({
    required this.article,
    required this.tint,
    required this.state,
    required this.onTap,
  });

  final String article;
  final Color tint;
  final _ArticleButtonState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (Color fill, Color border, Color text) = switch (state) {
      _ArticleButtonState.idle => (
          tint.withValues(alpha: 0.12),
          tint.withValues(alpha: 0.55),
          tint,
        ),
      _ArticleButtonState.correct => (
          tint.withValues(alpha: 0.22),
          tint,
          tint,
        ),
      _ArticleButtonState.wrong => (
          colors.error.withValues(alpha: 0.12),
          colors.error,
          colors.error,
        ),
      _ArticleButtonState.dimmed => (
          colors.card,
          colors.hairline,
          colors.textTertiary,
        ),
    };

    return AnimatedContainer(
      duration: context.motion.resolve(context, context.motion.quick),
      curve: context.motion.curve,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: context.radii.controlBorder,
        border: Border.all(
          color: border,
          width: state == _ArticleButtonState.correct ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: context.radii.controlBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radii.controlBorder,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
            child: Center(
              child: Text(
                article,
                style: AppTypography.monoStyle(
                  color: text,
                  size: 17,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleItem {
  const _ArticleItem({
    required this.article,
    required this.noun,
    required this.translation,
    required this.lesson,
  });

  final String article;
  final String noun;
  final String translation;
  final String lesson;
}
