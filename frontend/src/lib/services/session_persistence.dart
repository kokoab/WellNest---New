import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth token + admin flag so web refresh / app restart keeps the user signed in.
class SessionPersistence {
  SessionPersistence._();

  static const _kToken = 'wellnest_auth_token';
  static const _kIsAdmin = 'wellnest_is_admin';
  static const _kUserId = 'wellnest_user_id';

  static Future<void> write(
    String token, {
    required bool isAdmin,
    int? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setBool(_kIsAdmin, isAdmin);
    if (userId == null) {
      await prefs.remove(_kUserId);
    } else {
      await prefs.setInt(_kUserId, userId);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kIsAdmin);
    await prefs.remove(_kUserId);
  }

  /// Returns stored session, or `null` if none.
  static Future<({String token, bool isAdmin, int? userId})?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null || token.isEmpty) return null;
    final isAdmin = prefs.getBool(_kIsAdmin) ?? false;
    final userId = prefs.getInt(_kUserId);
    return (token: token, isAdmin: isAdmin, userId: userId);
  }
}
