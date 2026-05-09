import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/activity_log.dart';
import 'admin_auth_service.dart';

/// API calls for admin audit logs (list and CSV export).
class AdminAuditLogService {
  AdminAuditLogService._();
  static final AdminAuditLogService _instance = AdminAuditLogService._();
  static AdminAuditLogService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...AdminAuthService.instance.authHeaders,
  };

  /// GET /api/admin/audit-logs — paginated. Optional category, action.
  Future<ActivityLogListResponse> fetchLogs({
    int page = 1,
    String? category,
    String? action,
    String? range,
    String? search,
    List<String>? searchFields,
    DateTime? startDate,
    DateTime? endDate,
    int perPage = 50,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (action != null && action.isNotEmpty) params['action'] = action;
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
    params['per_page'] = '$perPage';
    final uri = Uri.parse(
      '$_baseUrl/admin/audit-logs',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return ActivityLogListResponse(
        logs: list
            .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentPage: data['current_page'] as int? ?? 1,
        lastPage: data['last_page'] as int? ?? 1,
        total: data['total'] as int? ?? 0,
      );
    }
    _throwFromResponse(response);
  }

  /// GET /api/admin/audit-logs/export — returns CSV bytes. Optional category/range.
  /// Caller is responsible for saving/sharing the file (e.g. via path_provider + share_plus).
  Future<List<int>> exportCsv({String category = 'all', String? range}) async {
    final params = <String, String>{};
    if (category.isNotEmpty && category != 'all') {
      params['category'] = category;
    }
    if (range != null && range.isNotEmpty) {
      params['range'] = range;
    }
    final uri = Uri.parse(
      '$_baseUrl/admin/audit-logs/export',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    _throwFromResponse(response);
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final message = data?['message'] as String?;
    throw Exception(message ?? 'Request failed: ${response.statusCode}');
  }
}

class ActivityLogListResponse {
  final List<ActivityLog> logs;
  final int currentPage;
  final int lastPage;
  final int total;
  ActivityLogListResponse({
    required this.logs,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}
