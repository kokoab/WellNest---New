import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/activity_log.dart';
import 'admin_auth_service.dart';

/// API calls for admin activity logs (list and CSV export).
class AdminActivityLogService {
  AdminActivityLogService._();
  static final AdminActivityLogService _instance = AdminActivityLogService._();
  static AdminActivityLogService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AdminAuthService.instance.authHeaders,
      };

  /// GET /api/admin/activity-logs — paginated. Optional category, action.
  Future<ActivityLogListResponse> fetchLogs({
    int page = 1,
    String? category,
    String? action,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (action != null && action.isNotEmpty) params['action'] = action;
    final uri = Uri.parse('$_baseUrl/admin/activity-logs').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return ActivityLogListResponse(
        logs: list.map((e) => ActivityLog.fromJson(e as Map<String, dynamic>)).toList(),
        currentPage: data['current_page'] as int? ?? 1,
        lastPage: data['last_page'] as int? ?? 1,
        total: data['total'] as int? ?? 0,
      );
    }
    _throwFromResponse(response);
  }

  /// GET /api/admin/activity-logs/export — returns CSV bytes. Optional category (default 'all').
  /// Caller is responsible for saving/sharing the file (e.g. via path_provider + share_plus).
  Future<List<int>> exportCsv({String category = 'all'}) async {
    final uri = category == 'all'
        ? Uri.parse('$_baseUrl/admin/activity-logs/export')
        : Uri.parse('$_baseUrl/admin/activity-logs/export').replace(queryParameters: {'category': category});
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
