import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/app_tokens.dart';
import 'primitives.dart';

/// How an answer choice is currently rendered.
enum ChoiceState { idle, selectedCorrect, selectedWrong, revealedCorrect }

/// One answer option.
///
/// State is carried by border and a tinted fill, never by a saturated flood -
/// a full-green or full-red button is the gamified look this design is
/// deliberately not.
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.monospace = false,
  });

  final String label;
  final ChoiceState state;
  final VoidCallback? onTap;

  /// Articles and other grammar tokens are set in mono so a column of them
  /// lines up.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (Color border, Color fill, Color text) = switch (state) {
      ChoiceState.idle => (colors.hairline, colors.card, colors.textPrimary),
      ChoiceState.selectedCorrect => (
          colors.success,
          colors.success.withValues(alpha: 0.12),
          colors.success,
        ),
      ChoiceState.selectedWrong => (
          colors.error,
          colors.error.withValues(alpha: 0.12),
          colors.error,
        ),
      ChoiceState.revealedCorrect => (
          colors.success.withValues(alpha: 0.6),
          colors.card,
          colors.success,
        ),
    };

    final style = monospace
        ? AppTypography.monoStyle(color: text, size: 17, weight: FontWeight.w600)
        : context.texts.bodyLarge?.copyWith(color: text);

    return AnimatedContainer(
      duration: context.motion.resolve(context, context.motion.quick),
      curve: context.motion.curve,
      margin: EdgeInsets.only(bottom: context.spacing.sm),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: context.radii.controlBorder,
        border: Border.all(color: border, width: state == ChoiceState.idle ? 1 : 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: context.radii.controlBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radii.controlBorder,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.lg,
              vertical: context.spacing.lg,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: style)),
                if (state == ChoiceState.selectedCorrect ||
                    state == ChoiceState.revealedCorrect)
                  Icon(Icons.check, size: 18, color: colors.success)
                else if (state == ChoiceState.selectedWrong)
                  Icon(Icons.close, size: 18, color: colors.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Outcome of an answer.
enum FeedbackKind { correct, almost, wrong }

/// Feedback as a statement of fact plus the correct form. No celebration, no
/// apology - the learner needs the right answer, not encouragement.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.kind,
    required this.headline,
    this.detail,
    this.trailing,
  });

  final FeedbackKind kind;
  final String headline;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = switch (kind) {
      FeedbackKind.correct => colors.success,
      FeedbackKind.almost => colors.warning,
      FeedbackKind.wrong => colors.error,
    };

    // A single leading bar rather than a full border: quieter, and it mirrors
    // correctly under RTL. AccentEdgeBox rather than a non-uniform border,
    // which would assert at paint time against the corner radius.
    return AccentEdgeBox(
      tint: tint,
      padding: EdgeInsets.all(context.spacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: context.texts.titleSmall?.copyWith(color: tint),
                ),
                if (detail != null) ...[
                  SizedBox(height: context.spacing.xs),
                  Text(
                    detail!,
                    style: AppTypography.monoStyle(
                      color: context.colors.textPrimary,
                      size: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Score readout for exercise app bars. Mono, because a number that changes in
/// place should not shift the glyphs around it.
class ScoreReadout extends StatelessWidget {
  const ScoreReadout({super.key, required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: context.spacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$value',
            style: AppTypography.monoStyle(
              color: context.colors.accentSoft,
              size: 17,
              weight: FontWeight.w600,
            ),
          ),
          SizedBox(width: context.spacing.xxs),
          Text(unit, style: context.texts.labelSmall),
        ],
      ),
    );
  }
}
