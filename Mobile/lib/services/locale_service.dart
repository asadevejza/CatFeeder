import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const _key = 'app_locale';
  static Future<String> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'bs';
  }
  static Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
