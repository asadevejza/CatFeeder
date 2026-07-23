import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

// Čuva/čita adresu backend servera lokalno na telefonu, preživljava restart app-a.
class SettingsService {
  static const _baseUrlKey = 'base_url';

  static Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
}
