import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deutsch_mate/theme/app_tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _ratio(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Composite a translucent foreground over its background before measuring -
/// the tinted chip fills are what a user actually sees.
Color _over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

void main() {
  // AA is 4.5:1 for body text and 3:1 for large text and UI boundaries.
  const bodyMin = 4.5;
  const largeMin = 3.0;
  const uiMin = 3.0;

  for (final (name, c) in [
    ('dark', AppColors.dark),
    ('light', AppColors.light),
  ]) {
    group('$name theme meets WCAG AA', () {
      // Body text sits on all three surface steps, so all three must pass.
      for (final (surfaceName, surface) in [
        ('scaffold', c.scaffold),
        ('surface', c.surface),
        ('card', c.card),
      ]) {
        test('primary text on $surfaceName', () {
          expect(
            _ratio(c.textPrimary, surface),
            greaterThanOrEqualTo(bodyMin),
            reason: 'primary text is body copy everywhere',
          );
        });

        test('secondary text on $surfaceName', () {
          expect(
            _ratio(c.textSecondary, surface),
            greaterThanOrEqualTo(bodyMin),
            reason: 'translations and subtitles are body copy',
          );
        });

        test('tertiary text on $surfaceName', () {
          // The audited palette specified #64707F here, which measures 3.75:1
          // and fails. This test is why the token was raised.
          expect(
            _ratio(c.textTertiary, surface),
            greaterThanOrEqualTo(bodyMin),
            reason: 'tertiary is still real text, not decoration',
          );
        });
      }

      test('soft accent, used for links and active labels, on surface', () {
        expect(
          _ratio(c.accentSoft, c.surface),
          greaterThanOrEqualTo(bodyMin),
        );
      });

      test('button label on the filled accent', () {
        final onAccent =
            name == 'dark' ? c.textPrimary : const Color(0xFFFFFFFF);
        expect(_ratio(onAccent, c.accent), greaterThanOrEqualTo(largeMin));
      });

      // Gender colours are read as text inside a tinted chip. Measured against
      // the composited chip fill, not the bare surface.
      for (final (article, tint) in [
        ('der', c.der),
        ('die', c.die),
        ('das', c.das),
      ]) {
        test('$article chip label on its own tint', () {
          final fill = _over(tint.withValues(alpha: 0.14), c.card);
          expect(
            _ratio(tint, fill),
            greaterThanOrEqualTo(largeMin),
            reason: 'article markers are short mono labels',
          );
        });
      }

      for (final (stateName, tint) in [
        ('success', c.success),
        ('warning', c.warning),
        ('error', c.error),
      ]) {
        test('$stateName headline on its banner fill', () {
          final fill = _over(tint.withValues(alpha: 0.10), c.card);
          expect(_ratio(tint, fill), greaterThanOrEqualTo(largeMin));
        });
      }

      test('hairline is a discernible boundary against card', () {
        expect(
          _ratio(c.hairline, c.card),
          greaterThanOrEqualTo(1.2),
          reason: 'a hairline is a 1px rule, not text - it only has to be seen',
        );
      });

      test('review accent on surface', () {
        expect(_ratio(c.review, c.surface), greaterThanOrEqualTo(uiMin));
      });
    });
  }

  test('the three gender colours are distinguishable from each other', () {
    // If two of them read as the same hue, the colour coding teaches nothing.
    for (final c in [AppColors.dark, AppColors.light]) {
      final pairs = [
        (c.der, c.die),
        (c.die, c.das),
        (c.der, c.das),
      ];
      for (final (a, b) in pairs) {
        final distance = math.sqrt(
          math.pow((a.r - b.r) * 255, 2) +
              math.pow((a.g - b.g) * 255, 2) +
              math.pow((a.b - b.b) * 255, 2),
        );
        expect(
          distance,
          greaterThan(90),
          reason: 'gender colours must not be confusable',
        );
      }
    }
  });
}
