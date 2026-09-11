import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_api.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/token_store.dart';
import 'core/progress/progress_store.dart';
import 'screens/auth/auth_gate.dart';
import 'widgets/progress_scope.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the first frame so the app never paints the wrong theme
  // and then swaps.
  final theme = await ThemeController.load();
  // Loaded before the first frame so Home never paints zeroes and then
  // corrects itself.
  final progress = await ProgressStore.load();

  final auth = AuthController(
    api: AuthApi(ApiClient()),
    tokenStore: SecureTokenStore(),
  );
  // Not awaited: the gate shows a splash while this runs, so a slow network
  // delays the first real screen rather than the first frame.
  unawaited(auth.bootstrap());

  runApp(
    DeutschMateApp(
      themeController: theme,
      authController: auth,
      progressStore: progress,
    ),
  );
}

class DeutschMateApp extends StatelessWidget {
  const DeutschMateApp({
    super.key,
    this.themeController,
    this.authController,
    this.progressStore,
  });

  /// Optional so tests and previews can construct the app without async setup.
  final ThemeController? themeController;
  final AuthController? authController;

  /// Optional so tests can build the app without async setup; screens that
  /// need it are only reachable once signed in.
  final ProgressStore? progressStore;

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

      builder: (context, child) {
        final body = ThemeScope(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        );
        final progress = progressStore;
        return progress == null
            ? body
            : ProgressScope(store: progress, child: body);
      },

      home: authController == null
          ? const _NoSessionPlaceholder()
          : AuthGate(controller: authController!),
    );
  }
}

/// Only reachable from tests and previews that build the app without wiring a
/// controller. Says so plainly rather than pretending to be a real screen.
class _NoSessionPlaceholder extends StatelessWidget {
  const _NoSessionPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('DeutschMate')));
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
