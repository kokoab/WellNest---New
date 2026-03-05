import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// In-memory store for user auth token. Used for authenticated API calls.
class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  String? _token;

  String? get token => _token;
  bool get isLoggedIn => _token != null;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get authHeaders {
    if (_token == null) return {};
    return {'Authorization': 'Bearer $_token'};
  }

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  /// POST /api/register with first_name, last_name, email, password. Returns null on success.
  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) setToken(token);
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg =
          data?['message'] as String? ??
          data?['errors']?.toString() ??
          'Registration failed';
      return msg;
    } catch (e) {
      return 'Failed to connect: $e';
    }
  }

  /// POST /api/login with email & password. Returns null on success.
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
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
        setToken(token);
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

  /// POST /api/logout with Bearer token. Clears local token.
  Future<void> logout() async {
    if (_token == null) {
      clearToken();
      return;
    }
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: {...authHeaders, 'Accept': 'application/json'},
      );
    } finally {
      clearToken();
    }
  }
}
