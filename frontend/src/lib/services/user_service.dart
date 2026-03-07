import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Current user model from GET /user.
class CurrentUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  CurrentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get displayName => '${firstName} ${lastName}'.trim();

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  static UserService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// GET /api/user — returns current authenticated user.
  Future<CurrentUser?> fetchCurrentUser() async {
    if (!AuthService.instance.isLoggedIn) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CurrentUser.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
