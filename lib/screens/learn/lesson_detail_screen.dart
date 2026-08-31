import 'package:flutter/material.dart';

import '../../core/german.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/gender_chip.dart';
import '../../widgets/primitives.dart';
import '../../widgets/speak_button.dart';

/// One Lektion: grammar, word field, example sentences.
///
/// The word list is where the gender colour-coding does most of its work - a
/// learner scanning this page sees three colours, not 30 identical rows.
class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key, required this.lessonData});

  final Map<String, dynamic> lessonData;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final words = (lessonData['words'] as List?) ?? const [];
    final sentences = (lessonData['sentences'] as List?) ?? const [];
    final title = lessonData['name']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(lessonData['title']?.toString() ?? ''),
        actions: [SpeakButton(text: title, size: 22)],
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
            title,
            style: context.texts.displaySmall,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
          ),
          SizedBox(height: spacing.sm),
          Text(
            lessonData['topic']?.toString() ?? '',
            style: context.texts.bodySmall,
          ),
          SizedBox(height: spacing.xl),

          // Grammar in mono on its own surface: it is a structure to be read
          // precisely, not prose.
          SectionHeader(title: 'ساختار', eyebrow: 'Grammatik'),
          AppCard(
            background: context.colors.surface,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                lessonData['grammar']?.toString() ?? '',
                style: AppTypography.monoStyle(
                  color: context.colors.textPrimary,
                  size: 13,
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
              ),
            ),
          ),
          SizedBox(height: spacing.xl),

          SectionHeader(
            title: 'واژگان',
            eyebrow: 'Wortschatz',
            trailing: Text('${words.length}', style: context.texts.labelSmall),
          ),
          for (final w in words)
            _VocabRow(
              entry: (w['word'] ?? '').toString(),
              translation: (w['translation'] ?? '').toString(),
            ),
          SizedBox(height: spacing.xl),

          SectionHeader(
            title: 'جمله‌ها',
            eyebrow: 'Redemittel',
            trailing:
                Text('${sentences.length}', style: context.texts.labelSmall),
          ),
          for (final s in sentences)
            _SentenceRow(
              german: (s['de'] ?? '').toString(),
              persian: (s['fa'] ?? '').toString(),
            ),
        ],
      ),
    );
  }
}

/// Reserved width for the article chip. Sized to the widest chip so the
/// German column is flush whether an entry has an article or not.
const double _articleSlot = 38;

class _VocabRow extends StatelessWidget {
  const _VocabRow({required this.entry, required this.translation});

  final String entry;
  final String translation;

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
          // Fixed slot whether or not there is an article, so the German words
          // line up in a column instead of going ragged on every entry that is
          // a verb or a proper noun.
          SizedBox(
            width: _articleSlot,
            child: noun.hasArticle
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: GenderChip(article: noun.article!, compact: true),
                  )
                : null,
          ),
          SizedBox(width: spacing.sm),
          // German hugs the start edge, Persian the end edge, gap in between.
          // Expanding the German instead put its glyphs right next to the
          // translation with all the empty space on the far side.
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

class _SentenceRow extends StatelessWidget {
  const _SentenceRow({required this.german, required this.persian});

  final String german;
  final String persian;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      margin: EdgeInsets.only(bottom: spacing.sm),
      // A leading rule instead of a full border: quieter, and it mirrors.
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
