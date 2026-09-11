import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/app_tokens.dart';

/// The shared vocabulary of the interface. Every screen is assembled from
/// these, which is why no screen contains a raw colour or size.

/// A surface one step lighter than its parent, with a hairline edge. This is
/// the elevation system - there is no shadow anywhere in the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final radius = context.radii.cardBorder;
    final body = Container(
      padding: padding ?? EdgeInsets.all(context.spacing.lg),
      decoration: BoxDecoration(
        color: background ?? context.colors.card,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? context.colors.hairline),
      ),
      child: child,
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: body),
    );
  }
}

/// Tracked, condensed, uppercase label - "LEKTION 07", "WORTSCHATZ".
///
/// Structural, not decorative: it names which part of the syllabus you are
/// looking at, which is information the Menschen course actually encodes.
class PlateLabel extends StatelessWidget {
  const PlateLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.plate(color ?? context.colors.textTertiary),
    );
  }
}

/// Section heading with an optional trailing action. The rule underneath is a
/// hairline, which is how the layout separates without ornament.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            PlateLabel(eyebrow!),
            SizedBox(height: context.spacing.xs),
          ],
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.texts.titleMedium),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: context.spacing.sm),
          Divider(color: context.colors.hairline, height: 1),
        ],
      ),
    );
  }
}

/// A single figure with its label. Numerals use the display face, which is
/// where that face earns its keep.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.tint,
  });

  final String value;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: context.texts.headlineMedium?.copyWith(
              color: tint ?? context.colors.textPrimary,
            ),
          ),
          SizedBox(height: context.spacing.xxs),
          Text(label, style: context.texts.labelSmall),
        ],
      ),
    );
  }
}

/// Progress as a hairline-thin bar. Deliberately not the accent blue unless it
/// is the loudest thing in the view - see [tint].
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.tint,
    this.height = 6,
  });

  final double value;
  final Color? tint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: context.radii.pillBorder,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: context.motion.resolve(context, context.motion.standard),
        curve: context.motion.curve,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: colors.inputFill,
          valueColor: AlwaysStoppedAnimation(tint ?? colors.accent),
        ),
      ),
    );
  }
}

/// Empty and error states are directions, not moods: what happened, and what
/// to do next. No apology, no exclamation mark, no illustration.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.action,
    this.icon,
  });

  final String title;
  final String action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28, color: context.colors.textTertiary),
              SizedBox(height: context.spacing.md),
            ],
            Text(
              title,
              style: context.texts.titleSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              action,
              style: context.texts.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A panel with an accent bar on its leading edge and rounded corners.
///
/// Exists because the obvious way to build this crashes. A `BoxDecoration`
/// whose border has non-uniform colours - a thick coloured start side, faint
/// sides - asserts at *paint* time when combined with a `borderRadius`:
///
///     'A borderRadius can only be given for borders with uniform colors.'
///
/// The widget still lays out, so the box appears but its contents never draw:
/// an empty coloured rectangle where the message should be. It is a paint-time
/// failure, so it survives any test that does not actually rasterise the
/// widget - which is how it reached a user here.
///
/// The fix is structural: a uniform border carries the radius, and the accent
/// bar is a child clipped to the same radius. Being a `Row` child, it mirrors
/// under RTL for free.
class AccentEdgeBox extends StatelessWidget {
  const AccentEdgeBox({
    super.key,
    required this.tint,
    required this.child,
    this.fillAlpha = 0.10,
    this.borderAlpha = 0.3,
    this.barWidth = 3,
    this.padding,
    this.background,
  });

  final Color tint;
  final Widget child;
  final double fillAlpha;
  final double borderAlpha;
  final double barWidth;
  final EdgeInsetsGeometry? padding;

  /// Overrides the tinted fill, for panels that sit on a card colour instead.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final radius = context.radii.controlBorder;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? tint.withValues(alpha: fillAlpha),
        borderRadius: radius,
        // Uniform, which is what makes the radius legal.
        border: Border.all(color: tint.withValues(alpha: borderAlpha)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: barWidth,
                child: ColoredBox(color: tint),
              ),
              Expanded(
                child: Padding(
                  padding: padding ?? EdgeInsets.all(context.spacing.md),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
