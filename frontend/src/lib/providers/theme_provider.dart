import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeKey = 'theme_mode';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemeKey);
      if (saved != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.system,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeKey, mode.name);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
