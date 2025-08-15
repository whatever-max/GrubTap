import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const _themeKey = "app_theme";
  static const _bgKey = "bg_path";

  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  static Future<String?> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey);
  }

  static Future<void> setBackgroundPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgKey, path);
  }

  static Future<String?> getBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bgKey);
  }
}
