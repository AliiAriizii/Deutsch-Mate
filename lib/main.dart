import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/auth_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolved before the first frame so the app never paints the wrong theme
  // and then swaps.
  final theme = await ThemeController.load();
  runApp(DeutschMateApp(themeController: theme));
}

class DeutschMateApp extends StatelessWidget {
  const DeutschMateApp({super.key, this.themeController});

  /// Optional so tests and previews can construct the app without async setup;
  /// they get the dark default.
  final ThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    if (controller == null) {
      return _app(ThemeController.defaultMode, null);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) => _app(controller.mode, controller),
    );
  }

  Widget _app(ThemeMode mode, ThemeController? controller) {
    return MaterialApp(
      title: 'DeutschMate',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,

      // The interface is Persian, so the whole layout has to mirror - padding,
      // icon order, list chevrons, the Lektion spine. Without a locale and the
      // delegates, Flutter lays Persian text out left-to-right and every
      // directional affordance points the wrong way.
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Exposed to the settings screen without a state-management package for
      // the single value that needs it.
      builder: (context, child) => ThemeScope(
        controller: controller,
        child: child ?? const SizedBox.shrink(),
      ),

      home: const AuthScreen(),
    );
  }
}

/// Makes the [ThemeController] reachable from the profile screen.
class ThemeScope extends InheritedWidget {
  const ThemeScope({super.key, required this.controller, required super.child});

  final ThemeController? controller;

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.controller;

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      controller != oldWidget.controller;
}
