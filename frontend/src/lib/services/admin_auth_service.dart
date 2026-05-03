import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'reverb_service.dart';
import 'session_persistence.dart';

/// In-memory store for admin auth token. Used for admin API calls.
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService _instance = AdminAuthService._();
  static AdminAuthService get instance => _instance;

  String? _token;
  bool _isAdmin = false;
  int? _userId;

  String? get token => _token;
  bool get isLoggedIn => _token != null && _isAdmin;
  int? get userId => _userId;

  void setAuth(String token, {required bool isAdmin}) {
    _token = token;
    _isAdmin = isAdmin;
  }

  void setUserId(int? userId) {
    _userId = userId;
  }

  void clearAuth() {
    _token = null;
    _isAdmin = false;
    _userId = null;
  }

  Map<String, String> get authHeaders {
    if (_token == null) return {};
    return {'Authorization': 'Bearer $_token'};
  }

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  /// POST /api/login-admin with email & password. On success stores token and sets isAdmin.
  /// Returns null on success, or error message string on failure.
  Future<String?> loginAdmin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login-admin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token == null || token.isEmpty)
          return 'Invalid response from server';
        setAuth(token, isAdmin: true);
        final admin = data['admin'] as Map<String, dynamic>?;
        setUserId(admin?['id'] as int?);
        await SessionPersistence.write(
          token,
          isAdmin: true,
          userId: admin?['id'] as int?,
        );
        return null;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        return data?['message'] as String? ?? 'Invalid credentials';
      }
      return 'Server error: ${response.statusCode}';
    } catch (e) {
      return 'Failed to connect: $e';
    }
  }

  /// POST /api/logout-admin with Bearer token. Clears local auth on success.
  Future<void> logoutAdmin() async {
    if (_token == null) {
      clearAuth();
      ReverbService.instance.disconnect();
      await SessionPersistence.clear();
      return;
    }
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout-admin'),
        headers: {...authHeaders, 'Accept': 'application/json'},
      );
    } finally {
      clearAuth();
      ReverbService.instance.disconnect();
      await SessionPersistence.clear();
    }
  }
}
