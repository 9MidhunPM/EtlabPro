import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode;
  ThemeNotifier(this._mode);

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  IconData get icon {
    switch (_mode) {
      case ThemeMode.dark:   return Icons.dark_mode_rounded;
      case ThemeMode.light:  return Icons.light_mode_rounded;
      case ThemeMode.system: return Icons.brightness_auto_rounded;
    }
  }

  String get tooltip {
    switch (_mode) {
      case ThemeMode.dark:   return 'Dark — tap for light';
      case ThemeMode.light:  return 'Light — tap for auto';
      case ThemeMode.system: return 'Auto — tap for dark';
    }
  }

  Future<void> toggle() async {
    switch (_mode) {
      case ThemeMode.dark:   _mode = ThemeMode.light;  break;
      case ThemeMode.light:  _mode = ThemeMode.system; break;
      case ThemeMode.system: _mode = ThemeMode.dark;   break;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _mode.name);
  }
}
