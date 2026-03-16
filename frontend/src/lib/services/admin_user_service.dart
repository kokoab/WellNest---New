import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/admin_user.dart';
import 'auth_service.dart';

/// API calls for admin user management (list, update status, delete).
class AdminUserService {
  AdminUserService._();
  static final AdminUserService _instance = AdminUserService._();
  static AdminUserService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// GET /api/admin/users — returns list of users.
  /// Returns list on success, or throws with message on error.
  Future<List<AdminUser>> fetchUsers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/users'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
    }
    _throwFromResponse(response);
  }

  /// PATCH /api/admin/users/{id}/status — set status to active or inactive.
  Future<AdminUser> updateUserStatus(int userId, String status) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/users/$userId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminUser.fromJson(data);
    }
    _throwFromResponse(response);
  }

  /// DELETE /api/admin/users/{id} — permanently delete user.
  Future<void> deleteUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/users/$userId'),
      headers: _headers,
    );
    if (response.statusCode == 204) return;
    _throwFromResponse(response);
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final message = data?['message'] as String?;
    final errors = data?['errors'] as Map<String, dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      final list = first is List ? first : [first];
      final msg = list.isNotEmpty ? list.first.toString() : message;
      throw Exception(msg ?? 'Request failed');
    }
    throw Exception(message ?? 'Request failed: ${response.statusCode}');
  }
}
