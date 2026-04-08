import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth token + admin flag so web refresh / app restart keeps the user signed in.
class SessionPersistence {
  SessionPersistence._();

  static const _kToken = 'wellnest_auth_token';
  static const _kIsAdmin = 'wellnest_is_admin';

  static Future<void> write(String token, {required bool isAdmin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setBool(_kIsAdmin, isAdmin);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kIsAdmin);
  }

  /// Returns stored session, or `null` if none.
  static Future<({String token, bool isAdmin})?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null || token.isEmpty) return null;
    final isAdmin = prefs.getBool(_kIsAdmin) ?? false;
    return (token: token, isAdmin: isAdmin);
  }
}
