import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'admin_auth_service.dart';
import 'reverb_service.dart';
import 'session_persistence.dart';

/// Result of [AuthService.login]: [error] is set on failure; [isAdmin] when login succeeds.
class LoginResult {
  final String? error;
  final bool isAdmin;

  const LoginResult._({this.error, this.isAdmin = false});

  factory LoginResult.failure(String message) =>
      LoginResult._(error: message, isAdmin: false);

  /// [isAdmin] is true when the user has `role` `admin` (same token works for admin routes).
  factory LoginResult.success({required bool isAdmin}) =>
      LoginResult._(error: null, isAdmin: isAdmin);

  bool get isSuccess => error == null;
}

/// In-memory store for user auth token. Used for authenticated API calls.
class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  String? _token;
  int? _userId;

  String? get token => _token;
  int? get userId => _userId;
  bool get isLoggedIn => _token != null;

  void setToken(String token) {
    _token = token;
  }

  void setUserId(int? userId) {
    _userId = userId;
  }

  void clearToken() {
    _token = null;
    _userId = null;
  }

  Map<String, String> get authHeaders {
    if (_token == null) return {};
    return {'Authorization': 'Bearer $_token'};
  }

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  /// POST /api/register with first_name, last_name, email, password, accepted_terms.
  /// Returns null on success.
  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required bool acceptedTerms,
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
          'accepted_terms': acceptedTerms,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          setToken(token);
          final user = data['user'] as Map<String, dynamic>?;
          final userId = user?['id'] as int?;
          setUserId(userId);
          await SessionPersistence.write(token, isAdmin: false, userId: userId);
        }
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

  /// POST /api/login with email & password.
  /// On success, syncs [AdminAuthService] when `user.role === 'admin'` so admin APIs work.
  Future<LoginResult> login(String email, String password) async {
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
        if (token == null || token.isEmpty) {
          return LoginResult.failure('Invalid response from server');
        }
        setToken(token);
        final user = data['user'] as Map<String, dynamic>?;
        final role = user?['role'] as String?;
        final isAdmin = role == 'admin';
        setUserId(user?['id'] as int?);
        if (isAdmin) {
          AdminAuthService.instance.setAuth(token, isAdmin: true);
        } else {
          AdminAuthService.instance.clearAuth();
        }
        await SessionPersistence.write(
          token,
          isAdmin: isAdmin,
          userId: user?['id'] as int?,
        );
        return LoginResult.success(isAdmin: isAdmin);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        return LoginResult.failure(
          data?['message'] as String? ?? 'Invalid credentials',
        );
      }
      return LoginResult.failure('Server error: ${response.statusCode}');
    } catch (e) {
      return LoginResult.failure('Failed to connect: $e');
    }
  }

  /// POST /api/forgot-password with the user's email address.
  Future<String?> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (response.statusCode == 200) {
        return data?['message'] as String? ??
            'If that email exists, a reset code has been sent.';
      }

      return data?['message'] as String? ?? 'Failed to request password reset';
    } catch (e) {
      return 'Failed to connect: $e';
    }
  }

  /// POST /api/reset-password with code, email, and the new password.
  Future<String?> resetPassword({
    required String code,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code': code.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (response.statusCode == 200) {
        return data?['message'] as String? ?? 'Password reset successfully.';
      }

      return data?['message'] as String? ?? 'Failed to reset password';
    } catch (e) {
      return 'Failed to connect: $e';
    }
  }

  /// POST /api/logout with Bearer token. Clears local token and admin session mirror.
  Future<void> logout() async {
    if (_token == null) {
      clearToken();
      AdminAuthService.instance.clearAuth();
      ReverbService.instance.disconnect();
      await SessionPersistence.clear();
      return;
    }
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: {...authHeaders, 'Accept': 'application/json'},
      );
    } finally {
      clearToken();
      AdminAuthService.instance.clearAuth();
      ReverbService.instance.disconnect();
      await SessionPersistence.clear();
    }
  }

  /// User-initiated deactivation. This calls the backend, then clears local auth.
  Future<void> deactivateAccount({String? reason}) async {
    if (_token == null) {
      clearToken();
      AdminAuthService.instance.clearAuth();
      ReverbService.instance.disconnect();
      await SessionPersistence.clear();
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/me/deactivate'),
        headers: {
          ...authHeaders,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        throw Exception(
          data?['message'] as String? ?? 'Failed to deactivate account',
        );
      }
    } finally {
      clearToken();
      AdminAuthService.instance.clearAuth();
      ReverbService.instance.disconnect();
      await SessionPersistence.clear();
    }
  }
}
