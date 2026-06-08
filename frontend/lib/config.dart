import 'package:shared_preferences/shared_preferences.dart';

/// App-wide configuration. The API base URL is persisted so you can point the
/// app at the Luma001 host (e.g. http://luma001:8000/api) without a rebuild.
class AppConfig {
  static const String _prefsKey = 'api_base_url';

  /// Default for local development.
  ///   - Android emulator: use http://10.0.2.2:8000/api
  ///   - iOS simulator / desktop / web: http://localhost:8000/api
  static const String defaultBaseUrl = 'http://localhost:8000/api';

  static String baseUrl = defaultBaseUrl;

  static const String _myPersonKey = 'my_person_id';

  /// Which Person this device acts as ("me"). Null until chosen in Settings.
  static int? myPersonId;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_prefsKey) ?? defaultBaseUrl;
    myPersonId = prefs.getInt(_myPersonKey);
  }

  static Future<void> setMyPersonId(int? id) async {
    myPersonId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_myPersonKey);
    } else {
      await prefs.setInt(_myPersonKey, id);
    }
  }

  static Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    baseUrl = cleaned.isEmpty ? defaultBaseUrl : cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, baseUrl);
  }
}
