import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the chosen theme mode and remembers it across launches.
///
/// The default is dark, not the platform setting. The palette was designed
/// against ink, that is what the app should open as, and following the OS meant
/// anyone on a light desktop got the light theme without ever asking for it.
/// Following the platform is still available - it is now a choice rather than
/// the default.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._mode);

  static const _prefsKey = 'theme_mode';
  static const defaultMode = ThemeMode.dark;

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  /// Reads the stored preference before the first frame, so the app never
  /// paints one theme and then swaps to the other.
  static Future<ThemeController> load() async {
    var mode = defaultMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      mode = _decode(prefs.getString(_prefsKey)) ?? defaultMode;
    } catch (e) {
      // A failed read is not worth blocking startup; fall back to the default.
      debugPrint('Theme preference unreadable: ${e.runtimeType}');
    }
    return ThemeController._(mode);
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(mode));
    } catch (e) {
      debugPrint('Theme preference not saved: ${e.runtimeType}');
    }
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };

  static ThemeMode? _decode(String? raw) => switch (raw) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => null,
      };
}
