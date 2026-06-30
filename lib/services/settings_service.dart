import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyAutoTheme = 'auto_theme';

  static Future<bool> getAutoTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoTheme) ?? false; // défaut : OFF
  }

  static Future<void> setAutoTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoTheme, value);
  }
}
