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

  // --- Auth -----------------------------------------------------------------
  static const String _authTokenKey = 'auth_token';
  static const String _authUsernameKey = 'auth_username';
  static const String _authPersonIdKey = 'auth_person_id';
  static const String _authPersonNameKey = 'auth_person_name';

  /// DRF token, sent as `Authorization: Token <token>`. Null when signed out.
  static String? authToken;

  /// The signed-in account and its linked Person (for display / default "me").
  static String? authUsername;
  static int? authPersonId;
  static String? authPersonName;

  static bool get isSignedIn => authToken != null;

  static const String _remindersKey = 'reminders_enabled';
  static const String _reminderHourKey = 'reminder_hour';
  static const String _reminderMinuteKey = 'reminder_minute';

  /// Whether on-device task reminders are scheduled.
  static bool remindersEnabled = true;

  /// Time of day reminders fire (24h clock). Defaults to 08:00.
  static int reminderHour = 8;
  static int reminderMinute = 0;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_prefsKey) ?? defaultBaseUrl;
    myPersonId = prefs.getInt(_myPersonKey);
    authToken = prefs.getString(_authTokenKey);
    authUsername = prefs.getString(_authUsernameKey);
    authPersonId = prefs.getInt(_authPersonIdKey);
    authPersonName = prefs.getString(_authPersonNameKey);
    remindersEnabled = prefs.getBool(_remindersKey) ?? true;
    reminderHour = prefs.getInt(_reminderHourKey) ?? 8;
    reminderMinute = prefs.getInt(_reminderMinuteKey) ?? 0;
  }

  /// Persist the token + who we are after a successful login.
  static Future<void> setAuth({
    required String token,
    required String username,
    int? personId,
    String? personName,
  }) async {
    authToken = token;
    authUsername = username;
    authPersonId = personId;
    authPersonName = personName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    await prefs.setString(_authUsernameKey, username);
    if (personId == null) {
      await prefs.remove(_authPersonIdKey);
    } else {
      await prefs.setInt(_authPersonIdKey, personId);
    }
    if (personName == null) {
      await prefs.remove(_authPersonNameKey);
    } else {
      await prefs.setString(_authPersonNameKey, personName);
    }
  }

  /// Forget the token + account on sign-out (or after a 401).
  static Future<void> clearAuth() async {
    authToken = null;
    authUsername = null;
    authPersonId = null;
    authPersonName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_authUsernameKey);
    await prefs.remove(_authPersonIdKey);
    await prefs.remove(_authPersonNameKey);
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

  static Future<void> setRemindersEnabled(bool value) async {
    remindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, value);
  }

  static Future<void> setReminderTime(int hour, int minute) async {
    reminderHour = hour;
    reminderMinute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
  }

  static Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    baseUrl = cleaned.isEmpty ? defaultBaseUrl : cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, baseUrl);
  }
}
