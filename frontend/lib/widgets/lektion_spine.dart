import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// State of one Lektion on the path.
enum SpineState { completed, current, available, locked }

/// The spine of light: a thin vertical rail running down the leading edge of
/// the Lektion path.
///
/// This is the one place boldness is spent. Everything else in the app stays
/// quiet, which is what lets this read as deliberate rather than decorative.
///
/// It also carries information rather than just position. Menschen groups 12
/// Lektionen into 4 Module of 3, and the rail shows that: a Lektion that opens
/// a Modul gets a wider node, so the syllabus structure is legible at a glance.
/// The current position gets the only bloom in the interface.
///
/// Direction-aware by construction. Under an RTL locale the rail sits on the
/// right, because a spine on the wrong edge reads as a rendering bug to a
/// Persian reader. Nothing here uses `left:` or `right:`.
class LektionSpine extends StatelessWidget {
  const LektionSpine({
    super.key,
    required this.state,
    required this.isFirst,
    required this.isLast,
    required this.opensModul,
    required this.label,
  });

  final SpineState state;
  final bool isFirst;
  final bool isLast;

  /// True for the first Lektion of a Modul - drawn as a wider node.
  final bool opensModul;

  /// Lektion number, shown inside the node.
  final String label;

  static const double railWidth = 2;
  static const double nodeSize = 30;
  static const double modulNodeSize = 38;

  Color _railColor(BuildContext context, {required bool trailing}) {
    final colors = context.colors;
    // A segment is lit only if the progress has passed it: the run above a
    // current node is lit, the run below is not.
    switch (state) {
      case SpineState.completed:
        return colors.accent;
      case SpineState.current:
        return trailing ? colors.hairline : colors.accent;
      case SpineState.available:
      case SpineState.locked:
        return colors.hairline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = opensModul ? modulNodeSize : nodeSize;
    final isCurrent = state == SpineState.current;
    final isDone = state == SpineState.completed;

    final nodeFill = switch (state) {
      SpineState.completed => colors.accent,
      SpineState.current => colors.scaffold,
      SpineState.available => colors.card,
      SpineState.locked => colors.surface,
    };
    final nodeBorder = switch (state) {
      SpineState.completed => colors.accent,
      SpineState.current => colors.accent,
      SpineState.available => colors.hairline,
      SpineState.locked => colors.hairline,
    };
    final labelColor = switch (state) {
      SpineState.completed => colors.scaffold,
      SpineState.current => colors.accentSoft,
      SpineState.available => colors.textSecondary,
      SpineState.locked => colors.textTertiary,
    };

    return SizedBox(
      width: modulNodeSize,
      child: Column(
        children: [
          // Leading rail run.
          Expanded(
            child: Center(
              child: Container(
                width: railWidth,
                color: isFirst
                    ? Colors.transparent
                    : _railColor(context, trailing: false),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: nodeFill,
              shape: BoxShape.circle,
              border: Border.all(
                color: nodeBorder,
                width: isCurrent ? 2 : 1,
              ),
              // The single bloom in the app, at the current position only.
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppPalette.glow(colors.accent),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isDone
                ? Icon(Icons.check, size: 15, color: colors.scaffold)
                : Text(
                    label,
                    style: context.texts.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          // Trailing rail run.
          Expanded(
            child: Center(
              child: Container(
                width: railWidth,
                color: isLast
                    ? Colors.transparent
                    : _railColor(context, trailing: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the Lektion path: spine on the leading edge, content beside it.
class SpineRow extends StatelessWidget {
  const SpineRow({
    super.key,
    required this.spine,
    required this.child,
    this.onTap,
  });

  final LektionSpine spine;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          spine,
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
