import 'package:flutter/material.dart';

/// Type system.
///
/// Three Latin faces with distinct jobs, plus a Persian face that every style
/// falls back to. All four are bundled, not fetched: the app is offline-first,
/// and a runtime font download would mean a first launch with no typography.
///
/// The bundled files are variable fonts - upstream publishes no static
/// instances - so weight and width are set through [FontVariation] rather than
/// by selecting a file. `fontWeight` is set alongside for the platforms that
/// map it themselves.
abstract final class AppTypography {
  /// Display: a grotesque with tight apertures and a width axis. Used only for
  /// screen titles and Lektion numerals, never for running text.
  static const display = 'Bricolage';

  /// Body and UI: high x-height neutral sans. Deliberately not the platform
  /// default, which is what makes an app look like a framework demo.
  static const body = 'Instrument';

  /// Utility: conjugation tables, article markers, IPA, exercise ids.
  /// Monospacing German grammar tables is the cheapest premium signal
  /// available, because it makes columns actually line up.
  static const mono = 'JetBrainsMono';

  /// Persian. Neither Latin face covers Arabic script, so without this
  /// fallback every Persian string renders as tofu boxes.
  static const persian = 'Vazirmatn';

  static const _fallback = [persian];

  static List<FontVariation> _axes(double weight, [double? width]) => [
        FontVariation('wght', weight),
        if (width != null) FontVariation('wdth', width),
      ];

  /// Lektion numerals and section eyebrows. Condensed and tightly tracked so
  /// "LEKTION 07" reads as a chapter plate rather than a label.
  static TextStyle plate(Color color) => TextStyle(
        fontFamily: display,
        fontFamilyFallback: _fallback,
        fontSize: 13,
        height: 1.1,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        fontVariations: _axes(700, 87.5),
        color: color,
      );

  /// Monospaced run for tables and article markers.
  static TextStyle monoStyle({
    required Color color,
    double size = 15,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: 1.35,
        letterSpacing: 0,
        fontWeight: weight,
        fontVariations: _axes(weight.value.toDouble()),
        color: color,
      );

  /// Scale: 32 / 24 / 20 / 17 / 15 / 13 / 11.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    TextStyle displayFace(
      double size,
      double weight, {
      double? width,
      double height = 1.12,
      double tracking = -0.4,
    }) =>
        TextStyle(
          fontFamily: display,
          fontFamilyFallback: _fallback,
          fontSize: size,
          height: height,
          letterSpacing: tracking,
          fontWeight: FontWeight.values.firstWhere(
            (w) => w.value >= weight,
            orElse: () => FontWeight.w700,
          ),
          fontVariations: _axes(weight, width),
          color: primary,
        );

    TextStyle bodyFace(
      double size,
      double weight, {
      double height = 1.45,
      double tracking = 0,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: body,
          fontFamilyFallback: _fallback,
          fontSize: size,
          height: height,
          letterSpacing: tracking,
          fontWeight: FontWeight.values.firstWhere(
            (w) => w.value >= weight,
            orElse: () => FontWeight.w700,
          ),
          fontVariations: _axes(weight),
          color: color ?? primary,
        );

    return TextTheme(
      // Screen titles. Condensed width is the personality of the page.
      displaySmall: displayFace(32, 700, width: 90),
      headlineMedium: displayFace(24, 600, width: 95),
      headlineSmall: displayFace(20, 600),

      titleLarge: bodyFace(20, 600, height: 1.25),
      titleMedium: bodyFace(17, 600, height: 1.3),
      titleSmall: bodyFace(15, 600, height: 1.3),

      bodyLarge: bodyFace(17, 400),
      bodyMedium: bodyFace(15, 400),
      bodySmall: bodyFace(13, 400, color: secondary, height: 1.4),

      labelLarge: bodyFace(13, 600, height: 1.2, tracking: 0.2),
      labelMedium: bodyFace(13, 500, height: 1.2, color: secondary),
      labelSmall: bodyFace(11, 500, height: 1.2, tracking: 0.4, color: secondary),
    );
  }
}
