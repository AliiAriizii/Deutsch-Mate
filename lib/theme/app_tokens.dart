import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Spacing, radii and motion.
///
/// `ThemeData` has no slot for any of these, so they travel as extensions.
/// That is what lets a widget file contain zero magic numbers: it reads
/// `context.spacing.md` instead of `16`.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xxs = 2,
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
    this.xxxl = 48,
    this.gutter = 20,
  });

  /// 4pt grid. `gutter` is the screen edge inset, deliberately not on the
  /// scale: 20 reads as generous at 360dp without wasting a whole step.
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double gutter;

  @override
  AppSpacing copyWith() => this;

  @override
  AppSpacing lerp(AppSpacing? other, double t) => this;
}

@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii();

  /// Three values, no exceptions. The audited codebase had seven.
  double get card => 12;
  double get control => 10;
  double get pill => 999;

  BorderRadius get cardBorder => BorderRadius.circular(card);
  BorderRadius get controlBorder => BorderRadius.circular(control);
  BorderRadius get pillBorder => BorderRadius.circular(pill);

  @override
  AppRadii copyWith() => this;

  @override
  AppRadii lerp(AppRadii? other, double t) => this;
}

@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion();

  Duration get quick => const Duration(milliseconds: 180);
  Duration get standard => const Duration(milliseconds: 220);
  Curve get curve => Curves.easeOutCubic;

  /// Honour the platform's reduce-motion setting: return zero so animated
  /// widgets settle instantly rather than being disabled case by case.
  Duration resolve(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

  @override
  AppMotion copyWith() => this;

  @override
  AppMotion lerp(AppMotion? other, double t) => this;
}

/// Colours that have no home in `ColorScheme`: grammatical gender, answer
/// feedback, and the surface ramp beyond `surface`/`surfaceContainer`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffold,
    required this.surface,
    required this.card,
    required this.inputFill,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentSoft,
    required this.accent,
    required this.accentStrong,
    required this.der,
    required this.die,
    required this.das,
    required this.review,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color scaffold;
  final Color surface;
  final Color card;
  final Color inputFill;
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The blue ramp. `accent` is the one saturated element per viewport;
  /// `accentSoft` is what everything else in the same view uses so two
  /// full-strength blues never compete.
  final Color accentSoft;
  final Color accent;
  final Color accentStrong;

  final Color der;
  final Color die;
  final Color das;
  final Color review;

  final Color success;
  final Color warning;
  final Color error;

  static const dark = AppColors(
    scaffold: AppPalette.ink900,
    surface: AppPalette.ink800,
    card: AppPalette.ink700,
    inputFill: AppPalette.ink600,
    hairline: AppPalette.inkHairline,
    textPrimary: AppPalette.darkTextPrimary,
    textSecondary: AppPalette.darkTextSecondary,
    textTertiary: AppPalette.darkTextTertiary,
    accentSoft: AppPalette.blue300,
    accent: AppPalette.blue500,
    accentStrong: AppPalette.blue600,
    der: AppPalette.derDark,
    die: AppPalette.dieDark,
    das: AppPalette.dasDark,
    review: AppPalette.reviewDark,
    success: AppPalette.successDark,
    warning: AppPalette.warningDark,
    error: AppPalette.errorDark,
  );

  static const light = AppColors(
    scaffold: AppPalette.paper000,
    surface: AppPalette.paper050,
    card: AppPalette.paper100,
    inputFill: AppPalette.paper200,
    hairline: AppPalette.paperHairline,
    textPrimary: AppPalette.lightTextPrimary,
    textSecondary: AppPalette.lightTextSecondary,
    textTertiary: AppPalette.lightTextTertiary,
    accentSoft: AppPalette.blue600,
    accent: AppPalette.blue500,
    accentStrong: AppPalette.blue600,
    der: AppPalette.derLight,
    die: AppPalette.dieLight,
    das: AppPalette.dasLight,
    review: AppPalette.reviewLight,
    success: AppPalette.successLight,
    warning: AppPalette.warningLight,
    error: AppPalette.errorLight,
  );

  /// Colour for a German definite article. Anything unrecognised falls back to
  /// secondary text rather than guessing a gender.
  Color forArticle(String? article) {
    switch (article?.trim().toLowerCase()) {
      case 'der':
        return der;
      case 'die':
        return die;
      case 'das':
        return das;
      default:
        return textSecondary;
    }
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      der: Color.lerp(der, other.der, t)!,
      die: Color.lerp(die, other.die, t)!,
      das: Color.lerp(das, other.das, t)!,
      review: Color.lerp(review, other.review, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// Terse access to the extensions. `context.colors.der` beats
/// `Theme.of(context).extension<AppColors>()!.der` at every call site.
extension AppThemeAccess on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;
  AppRadii get radii => Theme.of(this).extension<AppRadii>()!;
  AppMotion get motion => Theme.of(this).extension<AppMotion>()!;
  TextTheme get texts => Theme.of(this).textTheme;
}
