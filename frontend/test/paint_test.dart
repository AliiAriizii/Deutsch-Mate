// Widgets that must survive an actual paint pass.
//
// Written after a real escape: the error banner combined a non-uniform
// BorderDirectional with a corner radius, which asserts inside
// BoxDecoration.paint. Layout succeeded, so the box appeared - and its text
// never drew. A user saw an empty red rectangle instead of the reason their
// sign-in failed.
//
// Nothing in the existing suite caught it, because building and laying out a
// widget does not paint it. These tests force a paint and fail on any exception
// raised during it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deutsch_mate/theme/app_theme.dart';
import 'package:deutsch_mate/widgets/gender_chip.dart';
import 'package:deutsch_mate/widgets/lektion_spine.dart';
import 'package:deutsch_mate/widgets/primitives.dart';
import 'package:deutsch_mate/widgets/quiz_widgets.dart';

/// Pumps [child] in both themes and both text directions, and fails if
/// painting raises. RTL matters here because these widgets use directional
/// edges, which take a different code path than physical ones.
Future<void> expectPaints(
  WidgetTester tester,
  Widget child, {
  String? label,
}) async {
  for (final theme in [AppTheme.dark, AppTheme.light]) {
    for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(
                child: SizedBox(width: 360, child: child),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // takeException() returns whatever the framework caught during build,
      // layout or paint. Anything non-null means this widget cannot be drawn.
      expect(
        tester.takeException(),
        isNull,
        reason: '${label ?? child.runtimeType} failed to paint in '
            '${theme.brightness.name} / ${direction.name}',
      );
    }
  }
}

void main() {
  testWidgets('the shape AccentEdgeBox replaces really does fail to paint', (
    tester,
  ) async {
    // Pins the reason AccentEdgeBox exists, and proves these tests can fail.
    // A guard that passes against both the broken and the fixed code guards
    // nothing.
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Container(
              width: 200,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0x1AFF5C6B),
                borderRadius: BorderRadius.circular(10),
                border: const BorderDirectional(
                  start: BorderSide(color: Color(0xFFFF5C6B), width: 3),
                  top: BorderSide(color: Color(0x4DFF5C6B)),
                  bottom: BorderSide(color: Color(0x4DFF5C6B)),
                  end: BorderSide(color: Color(0x4DFF5C6B)),
                ),
              ),
              child: const Text('this text never draws'),
            ),
          ),
        ),
      ),
    );

    final error = tester.takeException();
    expect(
      error,
      isNotNull,
      reason: 'if this ever stops throwing, Flutter has lifted the '
          'uniform-colour restriction and AccentEdgeBox can be simplified',
    );
    expect(error.toString(), contains('uniform colors'));
  });

  testWidgets('AccentEdgeBox paints - the shape that used to assert', (
    tester,
  ) async {
    await expectPaints(
      tester,
      const AccentEdgeBox(
        tint: Color(0xFFFF5C6B),
        child: Text('پیام خطا'),
      ),
    );
  });

  testWidgets('every FeedbackBanner kind paints, with and without detail', (
    tester,
  ) async {
    for (final kind in FeedbackKind.values) {
      await expectPaints(
        tester,
        FeedbackBanner(kind: kind, headline: 'Richtig'),
        label: 'FeedbackBanner(${kind.name}) bare',
      );
      await expectPaints(
        tester,
        FeedbackBanner(
          kind: kind,
          headline: 'Falsch',
          detail: 'der Kalender',
          trailing: const Icon(Icons.volume_up_outlined),
        ),
        label: 'FeedbackBanner(${kind.name}) full',
      );
    }
  });

  testWidgets('every ChoiceButton state paints', (tester) async {
    for (final state in ChoiceState.values) {
      await expectPaints(
        tester,
        ChoiceButton(label: 'das', state: state, onTap: () {}),
        label: 'ChoiceButton(${state.name})',
      );
      await expectPaints(
        tester,
        ChoiceButton(
          label: 'das',
          state: state,
          onTap: () {},
          monospace: true,
        ),
        label: 'ChoiceButton(${state.name}) mono',
      );
    }
  });

  testWidgets('the gender chips paint in both sizes', (tester) async {
    for (final article in ['der', 'die', 'das']) {
      await expectPaints(
        tester,
        GenderChip(article: article),
        label: 'GenderChip($article)',
      );
      await expectPaints(
        tester,
        GenderChip(article: article, compact: true),
        label: 'GenderChip($article) compact',
      );
    }
    await expectPaints(tester, const GenderLegend());
  });

  testWidgets('every LektionSpine state paints, including the glow', (
    tester,
  ) async {
    // The current node carries the only boxShadow in the app, which is its own
    // paint path.
    for (final state in SpineState.values) {
      for (final opensModul in [true, false]) {
        await expectPaints(
          tester,
          SpineRow(
            spine: LektionSpine(
              state: state,
              isFirst: false,
              isLast: false,
              opensModul: opensModul,
              label: '7',
            ),
            child: const AppCard(child: Text('Lektion')),
          ),
          label: 'LektionSpine(${state.name}, modul=$opensModul)',
        );
      }
    }
  });

  testWidgets('the remaining primitives paint', (tester) async {
    await expectPaints(tester, const AppCard(child: Text('کارت')));
    await expectPaints(tester, const PlateLabel('LEKTION 07'));
    await expectPaints(
      tester,
      const SectionHeader(title: 'واژگان', eyebrow: 'Wortschatz'),
    );
    await expectPaints(
      tester,
      const StatTile(value: '148', label: 'اسم با آرتیکل'),
    );
    await expectPaints(tester, const AppProgressBar(value: 0.33));
    await expectPaints(
      tester,
      const EmptyState(
        title: 'چیزی نیست',
        action: 'درس دیگری انتخاب کن.',
        icon: Icons.filter_alt_outlined,
      ),
    );
    await expectPaints(
      tester,
      const ScoreReadout(value: 40, unit: 'XP'),
    );
  });
}
