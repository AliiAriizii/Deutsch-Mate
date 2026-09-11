// Smoke tests for the app shell.
//
// The app now boots through AuthGate, so these construct a controller wired to
// a scripted server rather than instantiating screens directly - which is also
// what makes the "which screen does a cold start land on" question testable.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deutsch_mate/core/api/api_client.dart';
import 'package:deutsch_mate/core/auth/auth_api.dart';
import 'package:deutsch_mate/core/auth/auth_controller.dart';
import 'package:deutsch_mate/core/auth/token_store.dart';
import 'package:deutsch_mate/main.dart';
import 'package:deutsch_mate/screens/auth/auth_screen.dart';
import 'package:deutsch_mate/theme/theme_controller.dart';

/// A controller whose server answers 404 to everything: nothing is stored, so
/// bootstrap settles on signedOut without any network being reachable.
AuthController offlineController() => AuthController(
      api: AuthApi(
        ApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {'code': 'NOT_FOUND', 'message': 'x'},
              }),
              404,
              headers: {'content-type': 'application/json'},
            ),
          ),
          baseUrl: 'http://test',
        ),
      ),
      tokenStore: InMemoryTokenStore(),
    );

Future<AuthController> pumpApp(WidgetTester tester) async {
  final auth = offlineController();
  await auth.bootstrap();
  await tester.pumpWidget(
    DeutschMateApp(
      themeController: null,
      authController: auth,
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('a cold start with no session lands on the auth screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    // The primary CTA plus the Google button.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('the Persian interface lays out right-to-left', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // Without a locale and the localisation delegates, Flutter lays Persian
    // text out LTR and every directional affordance points the wrong way.
    final context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the auth screen toggles between sign in and sign up', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final signInFields = find.byType(TextFormField).evaluate().length;

    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    // Sign-up mode adds the name field.
    expect(find.byType(TextFormField).evaluate().length,
        greaterThan(signInFields));
  });

  testWidgets('a restoring session shows a splash, never the auth screen', (
    WidgetTester tester,
  ) async {
    // The "no flash of the wrong screen" rule, asserted at the widget layer:
    // before bootstrap resolves, the auth screen must not be on the tree.
    final auth = offlineController();
    await tester.pumpWidget(DeutschMateApp(authController: auth));
    await tester.pump();

    expect(auth.stage, AuthStage.restoring);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await auth.bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  test('the default theme mode is dark', () {
    // Guards the regression where following the OS gave light-mode users the
    // light theme unasked.
    expect(ThemeController.defaultMode, ThemeMode.dark);
  });
}
