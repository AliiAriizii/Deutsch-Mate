import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the rule that makes the theme layer worth having: no widget file
/// invents its own colours or type sizes.
///
/// This is the acceptance criterion as an executable check, so it cannot rot
/// the way a one-off grep does.
void main() {
  final themeDir = 'lib${Platform.pathSeparator}theme';

  List<File> widgetFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains(themeDir))
      .toList();

  test('no hardcoded colours outside lib/theme', () {
    final offenders = <String>[];

    for (final file in widgetFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;

        if (line.contains('Color(0x')) {
          offenders.add('${file.path}:${i + 1}  $line');
        }
        // Colors.transparent has no palette equivalent and cannot drift;
        // every other Colors.* constant is a bypass of the theme.
        final material = RegExp(r'Colors\.(?!transparent)\w+').firstMatch(line);
        if (material != null) {
          offenders.add('${file.path}:${i + 1}  ${material.group(0)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Colours belong in lib/theme:\n${offenders.join('\n')}',
    );
  });

  test('no hardcoded font sizes outside lib/theme', () {
    final offenders = <String>[];

    for (final file in widgetFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (lines[i].contains('fontSize:')) {
          offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Type sizes come from the TextTheme or AppTypography:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no emoji anywhere in lib', () {
    // The brief is explicit: no emoji. They were also the one glyph class the
    // bundled fonts do not cover, so they rendered as tofu boxes.
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|[\u{1F1E6}-\u{1F1FF}]|\u{FE0F}',
      unicode: true,
    );
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (emoji.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Emoji found:\n${offenders.join('\n')}',
    );
  });

  test('no left/right padding or borders, which do not mirror under RTL', () {
    // The interface is Persian. EdgeInsets.only(left:) and Border(left:) are
    // physically anchored and break mirroring; the directional variants do not.
    final offenders = <String>[];
    final physical = RegExp(
      r'EdgeInsets\.only\([^)]*\b(left|right)\s*:|'
      r'(?<!Directional)\bBorder\(\s*(left|right)\s*:',
    );

    for (final file in widgetFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (physical.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use EdgeInsetsDirectional / BorderDirectional:\n'
          '${offenders.join('\n')}',
    );
  });
}
