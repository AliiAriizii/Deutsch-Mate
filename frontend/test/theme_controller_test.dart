import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deutsch_mate/theme/theme_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('the default is dark, not the platform setting', () async {
    // Following the OS meant anyone on a light desktop silently got the light
    // theme. Dark is what the palette was designed against.
    expect(ThemeController.defaultMode, ThemeMode.dark);

    final controller = await ThemeController.load();
    expect(controller.mode, ThemeMode.dark);
  });

  test('a choice survives a restart', () async {
    final first = await ThemeController.load();
    await first.set(ThemeMode.light);

    final second = await ThemeController.load();
    expect(second.mode, ThemeMode.light);
  });

  test('system is selectable, so following the platform stays available',
      () async {
    final controller = await ThemeController.load();
    await controller.set(ThemeMode.system);

    final reloaded = await ThemeController.load();
    expect(reloaded.mode, ThemeMode.system);
  });

  test('an unrecognised stored value falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final controller = await ThemeController.load();
    expect(controller.mode, ThemeMode.dark);
  });

  test('setting the current mode again notifies nothing', () async {
    final controller = await ThemeController.load();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(ThemeMode.dark); // already dark
    expect(notifications, 0);

    await controller.set(ThemeMode.light);
    expect(notifications, 1);
  });
}
