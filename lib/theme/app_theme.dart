import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// The single source of visual truth.
///
/// Every colour, size, radius and duration in the app resolves here. Widget
/// files contain no `Color(0x...)`, no `fontSize:`, and no bare numbers for
/// spacing - enforced by test/theme_no_hardcoded_values_test.dart.
abstract final class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    const spacing = AppSpacing();
    const radii = AppRadii();

    final textTheme = AppTypography.textTheme(
      primary: c.textPrimary,
      secondary: c.textSecondary,
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: brightness == Brightness.dark
          ? AppPalette.darkTextPrimary
          : AppPalette.paperRaised,
      primaryContainer: c.accentStrong,
      onPrimaryContainer: AppPalette.darkTextPrimary,
      secondary: c.accentSoft,
      onSecondary: c.scaffold,
      tertiary: c.review,
      onTertiary: AppPalette.darkTextPrimary,
      error: c.error,
      onError: brightness == Brightness.dark
          ? AppPalette.ink900
          : AppPalette.paperRaised,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.scaffold,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.inputFill,
      surfaceContainerHighest: c.inputFill,
      outline: c.hairline,
      outlineVariant: c.hairline,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.scaffold,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.scaffold,
      canvasColor: c.scaffold,
      textTheme: textTheme,
      fontFamily: AppTypography.body,

      // Depth is surface lightness plus a hairline. Never a shadow.
      shadowColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,

      extensions: <ThemeExtension<dynamic>>[
        c,
        spacing,
        radii,
        const AppMotion(),
      ],

      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: c.textSecondary, size: 22),
        actionsIconTheme: IconThemeData(color: c.textSecondary, size: 22),
      ),

      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radii.cardBorder,
          side: BorderSide(color: c.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.inputFill;
            if (states.contains(WidgetState.pressed)) return c.accentStrong;
            return c.accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.textTertiary;
            return scheme.onPrimary;
          }),
          overlayColor: WidgetStateProperty.all(
            AppPalette.glow(AppPalette.blue300),
          ),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: radii.controlBorder),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          elevation: WidgetStateProperty.all(0),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(c.textPrimary),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: c.accent);
            }
            return BorderSide(color: c.hairline);
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return c.inputFill;
            return Colors.transparent;
          }),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: radii.controlBorder),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(c.accentSoft),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          overlayColor: WidgetStateProperty.all(
            AppPalette.glow(AppPalette.blue300),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: radii.controlBorder),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.textTertiary;
            return c.textSecondary;
          }),
          overlayColor: WidgetStateProperty.all(
            AppPalette.glow(AppPalette.blue300),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: c.accentSoft),
        helperStyle: textTheme.labelSmall,
        errorStyle: textTheme.labelMedium?.copyWith(color: c.error),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textSecondary,
        border: OutlineInputBorder(
          borderRadius: radii.controlBorder,
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radii.controlBorder,
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radii.controlBorder,
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radii.controlBorder,
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radii.controlBorder,
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.glow(AppPalette.blue500),
        indicatorShape: RoundedRectangleBorder(borderRadius: radii.pillBorder),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.accentSoft, size: 22);
          }
          return IconThemeData(color: c.textTertiary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: c.accentSoft,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(color: c.textTertiary);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.inputFill,
        side: BorderSide(color: c.hairline),
        labelStyle: textTheme.labelMedium!,
        shape: RoundedRectangleBorder(borderRadius: radii.pillBorder),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xs,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.inputFill,
        circularTrackColor: c.inputFill,
        linearMinHeight: 6,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.card,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: c.accentSoft,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radii.controlBorder,
          side: BorderSide(color: c.hairline),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(c.card),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: radii.controlBorder,
              side: BorderSide(color: c.hairline),
            ),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: EdgeInsets.symmetric(horizontal: spacing.lg),
        minVerticalPadding: spacing.md,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: radii.controlBorder,
          border: Border.all(color: c.hairline),
        ),
        textStyle: textTheme.labelMedium,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
