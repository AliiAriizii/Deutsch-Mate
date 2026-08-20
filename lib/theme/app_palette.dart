import 'package:flutter/material.dart';

/// Raw colour tokens. Nothing outside `lib/theme/` refers to these directly -
/// widgets read them through `ColorScheme` or the theme extensions.
///
/// Two rules govern this palette:
///
/// 1. **Depth comes from surface lightness and 1px hairlines, never from
///    shadow.** The five surface steps are the elevation system.
/// 2. **Every hue outside the blue ramp has a job.** The grammar triad encodes
///    German grammatical gender the way a textbook does; the state colours
///    encode answer feedback. There is no decorative colour.
abstract final class AppPalette {
  // ---------------------------------------------------------------- dark ----

  /// Scaffold. Not #000000 - pure black flattens the surfaces above it.
  static const ink900 = Color(0xFF07090D);
  static const ink800 = Color(0xFF0D1117);
  static const ink700 = Color(0xFF131A24);
  static const ink600 = Color(0xFF1C2531);
  static const inkHairline = Color(0xFF263140);

  static const blue300 = Color(0xFF8FB4FF);
  static const blue400 = Color(0xFF4E86FF);
  static const blue500 = Color(0xFF2F6BFF);
  static const blue600 = Color(0xFF1E4FD1);

  static const darkTextPrimary = Color(0xFFEDF1F7);
  static const darkTextSecondary = Color(0xFF9AA7B8);

  /// Raised from the specified #64707F, which measures 3.75:1 on ink800 and
  /// fails WCAG AA for body text. #7C889A clears 4.5:1. Verified in
  /// test/theme_contrast_test.dart.
  static const darkTextTertiary = Color(0xFF7C889A);

  // --------------------------------------------------------------- light ----
  // The dark ramp expresses elevation by getting *lighter* each step. That
  // logic cannot simply be mirrored onto white: a card lighter than a white
  // scaffold is impossible, and a card slightly darker than white reads as
  // dirty rather than raised. So the light ramp inverts the direction - the
  // ground is tinted and cards rise to pure white above it.

  /// Tinted ground, not white. The scaffold is the darkest light surface.
  static const paperGround = Color(0xFFEDF1F7);

  /// Sunken panels: grammar blocks, filter bars.
  static const paperSunken = Color(0xFFF4F7FB);

  /// Cards. The brightest surface, so elevation reads as "closer to the light".
  static const paperRaised = Color(0xFFFFFFFF);

  /// Input fills sit below the card they live on.
  static const paperInput = Color(0xFFE4EAF3);

  /// Stronger than the dark theme's hairline: on light surfaces a 1px rule has
  /// to work harder to register at all.
  static const paperHairline = Color(0xFFC9D3E0);

  static const lightTextPrimary = Color(0xFF0B1220);
  static const lightTextSecondary = Color(0xFF47566B);

  /// Same story as darkTextTertiary: #6B7A8F fails AA on the light surfaces.
  static const lightTextTertiary = Color(0xFF56657A);

  // ------------------------------------------------- grammatical gender ----
  // The signature of this palette. German nouns carry gender, learners get it
  // wrong more than anything else, and colour-coding it is long-established
  // classroom practice. These are deliberately medium-saturation "printed
  // ink" tones, always rendered as a tinted chip with a hairline border and a
  // monospaced article - so they read as material, not as a second call to
  // action competing with the primary button.

  static const derDark = Color(0xFF3E8FD9); // azure
  static const dieDark = Color(0xFFC9508A); // mulberry
  static const dasDark = Color(0xFF4FA96B); // fern

  static const derLight = Color(0xFF1F6BAA);
  static const dieLight = Color(0xFFA3306B);
  static const dasLight = Color(0xFF2E7A4B);

  /// Spaced repetition. A card that is due is in a different mode from new
  /// material, and that distinction deserves its own hue rather than another
  /// shade of blue.
  static const reviewDark = Color(0xFF8A7CF0);
  static const reviewLight = Color(0xFF5744C4);

  // ----------------------------------------------------- answer feedback ----
  // Higher saturation than the grammar triad on purpose: these appear as
  // short-lived banners and borders, so the two systems never read as one
  // even where their hues are adjacent.

  static const successDark = Color(0xFF35C48A);
  static const warningDark = Color(0xFFE5A93C);
  static const errorDark = Color(0xFFFF5C6B);

  static const successLight = Color(0xFF10714E);
  static const warningLight = Color(0xFF8A5B0B);
  static const errorLight = Color(0xFFC2233A);

  // --------------------------------------------------------------- glow ----

  /// Focus rings and the single bloom at the current position on the Lektion
  /// spine. The only place a soft glow is permitted.
  static Color glow(Color base) => base.withValues(alpha: 0.28);

  /// The one sanctioned shadow: neutral, tight, barely there. Colour-tinted or
  /// wide-blur shadows are what make an interface look cheap.
  static const List<BoxShadow> restrainedShadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 2)),
  ];
}
