// Smoke test: the app boots and lands on the auth screen.
//
// Replaced the stock counter-app template, which referenced a `MyApp` class
// that never existed in this project (the app widget is `DeutschMateApp`) and
// therefore failed to compile.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deutsch_mate/main.dart';

void main() {
  testWidgets('app boots into the auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DeutschMateApp());
    await tester.pumpAndSettle();

    // The auth screen is the entry point, and it offers both modes.
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('auth screen toggles between sign in and sign up', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DeutschMateApp());
    await tester.pumpAndSettle();

    // Sign-in mode shows email + password only.
    final signInFields = find.byType(TextFormField).evaluate().length;

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    // Sign-up mode adds name and phone.
    final signUpFields = find.byType(TextFormField).evaluate().length;
    expect(signUpFields, greaterThan(signInFields));
  });
}
