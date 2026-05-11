import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/admin_user.dart';
import 'admin_auth_service.dart';

class AdminApiException implements Exception {
  final int statusCode;
  final String message;

  const AdminApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Result class for fetching users
class FetchUsersResult {
  final List<AdminUser> users;
  final int total;
  final int activeTotal;
  final int currentPage;
  final int lastPage;

  FetchUsersResult({
    required this.users,
    required this.total,
    required this.activeTotal,
    required this.currentPage,
    required this.lastPage,
  });
}

/// API calls for admin user management (list, update status, delete).
class AdminUserService {
  AdminUserService._();
  static final AdminUserService _instance = AdminUserService._();
  static AdminUserService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...AdminAuthService.instance.authHeaders,
  };

  /// GET /api/admin/users — returns list of users.
  /// Fetch users, supports optional `range`, `search`, and pagination.
  /// Returns FetchUsersResult with users list and total count from API.
  Future<FetchUsersResult> fetchUsers({
    String? range,
    String? search,
    List<String>? searchFields,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{};
    if (range != null && range.isNotEmpty) params['range'] = range;
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (searchFields != null && searchFields.isNotEmpty) {
      params['search_fields'] = searchFields.join(',');
    }
    if (startDate != null) {
      params['start_date'] = startDate.toIso8601String().split('T').first;
    }
    if (endDate != null) {
      params['end_date'] = endDate.toIso8601String().split('T').first;
    }
    params['page'] = '$page';
    params['per_page'] = '$perPage';

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/admin/users',
      ).replace(queryParameters: params.isEmpty ? null : params),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List
          ? body
          : (body is Map<String, dynamic> && body['data'] is List
                ? body['data'] as List<dynamic>
                : <dynamic>[]);
      final users = list
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();

      // Extract total count from meta (JSON numbers may decode as double on web).
      int total = users.length;
      int activeTotal = 0;
      int currentPage = 1;
      int lastPage = 1;
      if (body is Map<String, dynamic> && body['meta'] is Map) {
        final meta = body['meta'] as Map<String, dynamic>;
        total = _jsonInt(meta['total'], users.length);
        activeTotal = _jsonInt(meta['active_total'], 0);
        currentPage = _jsonInt(meta['current_page'], 1);
        lastPage = _jsonInt(meta['last_page'], 1);
      }

      return FetchUsersResult(
        users: users,
        total: total,
        activeTotal: activeTotal,
        currentPage: currentPage,
        lastPage: lastPage,
      );
    }
    _throwFromResponse(response);
  }

  /// Parses Laravel pagination meta integers; avoids cast errors when JSON uses doubles (e.g. Flutter web).
  static int _jsonInt(Object? value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// PATCH /api/admin/users/{id}/status — set status to active or inactive.
  Future<AdminUser> updateUserStatus(int userId, String status) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/users/$userId/status'),
      headers: _headers,
      body: jsonEncode({'account_status': status}),
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
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      data = null;
    }

    final message = data?['message'] as String?;
    final errors = data?['errors'] as Map<String, dynamic>?;

    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      final list = first is List ? first : [first];
      final msg = list.isNotEmpty ? list.first.toString() : message;
      throw AdminApiException(response.statusCode, msg ?? 'Request failed');
    }

    throw AdminApiException(
      response.statusCode,
      message ?? 'Request failed: ${response.statusCode}',
    );
  }
}
