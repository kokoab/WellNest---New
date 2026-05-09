import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/report.dart';
import 'admin_auth_service.dart';

/// API calls for admin content moderation (reports).
class AdminModerationService {
  AdminModerationService._();
  static final AdminModerationService _instance = AdminModerationService._();
  static AdminModerationService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...AdminAuthService.instance.authHeaders,
  };

  /// GET /api/admin/reports — pending reports (supports paginated and legacy list responses).
  Future<AdminReportsResponse> fetchReportsPaginated({
    String? range,
    String? search,
    List<String>? searchFields,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int perPage = 20,
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
        '$_baseUrl/admin/reports',
      ).replace(queryParameters: params.isEmpty ? null : params),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List<dynamic>) {
        final reports = body
            .map((e) => Report.fromJson(e as Map<String, dynamic>))
            .toList();
        return AdminReportsResponse(
          reports: reports,
          currentPage: page,
          lastPage: 1,
          total: reports.length,
          perPage: perPage,
        );
      }
      if (body is Map<String, dynamic>) {
        final list = (body['data'] as List<dynamic>?) ?? [];
        return AdminReportsResponse(
          reports: list
              .map((e) => Report.fromJson(e as Map<String, dynamic>))
              .toList(),
          currentPage: (body['current_page'] as num?)?.toInt() ?? page,
          lastPage: (body['last_page'] as num?)?.toInt() ?? page,
          total: (body['total'] as num?)?.toInt() ?? list.length,
          perPage: (body['per_page'] as num?)?.toInt() ?? perPage,
        );
      }
    }
    _throwFromResponse(response);
  }

  Future<List<Report>> fetchReports({
    String? range,
    String? search,
    List<String>? searchFields,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await fetchReportsPaginated(
      range: range,
      search: search,
      searchFields: searchFields,
      startDate: startDate,
      endDate: endDate,
      page: page,
      perPage: perPage,
    );
    return res.reports;
  }

  /// PATCH /api/admin/reports/{report}/approve
  Future<void> approve(int reportId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/reports/$reportId/approve'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// PATCH /api/admin/reports/{report}/dismiss
  Future<void> dismiss(int reportId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/reports/$reportId/dismiss'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// PATCH /api/admin/reports/{report}/remove-content
  Future<void> removeContent(int reportId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/reports/$reportId/remove-content'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// PATCH /api/admin/reports/{report}/suspend-user
  Future<void> suspendUser(int reportId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/reports/$reportId/suspend-user'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// PATCH /api/admin/reports/{report}/unban-user
  Future<void> unbanUser(int reportId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/admin/reports/$reportId/unban-user'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// DELETE /api/admin/reports — delete all pending reports.
  Future<void> deleteAllReports() async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/reports'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
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

class AdminReportsResponse {
  final List<Report> reports;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const AdminReportsResponse({
    required this.reports,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });
}
