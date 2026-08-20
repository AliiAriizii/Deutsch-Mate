import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/app_tokens.dart';

/// A definite article, colour-coded by gender.
///
/// The signature element of the palette. German nouns carry gender, learners
/// get it wrong more than anything else, and colour-coding it is established
/// classroom practice - so the colour here is doing pedagogical work, not
/// decoration.
///
/// Rendered as a tinted fill with a hairline border and a monospaced label, so
/// it reads as a printed marker rather than as a button competing with the
/// primary action.
class GenderChip extends StatelessWidget {
  const GenderChip({super.key, required this.article, this.compact = false});

  final String article;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = colors.forArticle(article);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? context.spacing.sm : context.spacing.md,
        vertical: compact ? context.spacing.xxs : context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: context.radii.pillBorder,
        border: Border.all(color: tint.withValues(alpha: 0.55)),
      ),
      child: Text(
        article.toLowerCase(),
        style: AppTypography.monoStyle(
          color: tint,
          size: compact ? 11 : 13,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The three articles side by side, for a legend or an answer row.
class GenderLegend extends StatelessWidget {
  const GenderLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.spacing.sm,
      children: const [
        GenderChip(article: 'der', compact: true),
        GenderChip(article: 'die', compact: true),
        GenderChip(article: 'das', compact: true),
      ],
    );
  }
}
