import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/json_helpers.dart';
import 'admin_auth_service.dart';

class AdminOverviewStats {
  final int totalUsers;
  final int totalPosts;
  final int totalConversations;
  final int activeUsers;
  final int inactiveUsers;

  const AdminOverviewStats({
    required this.totalUsers,
    required this.totalPosts,
    required this.totalConversations,
    required this.activeUsers,
    required this.inactiveUsers,
  });

  factory AdminOverviewStats.fromJson(Map<String, dynamic> json) {
    return AdminOverviewStats(
      totalUsers: jsonDecodeInt(json['total_users']),
      totalPosts: jsonDecodeInt(json['total_posts']),
      totalConversations: jsonDecodeInt(json['total_conversations']),
      activeUsers: jsonDecodeInt(json['active_users']),
      inactiveUsers: jsonDecodeInt(json['inactive_users']),
    );
  }
}

class AdminStatPoint {
  final DateTime date;
  final int count;

  /// Server-provided x-axis label (e.g. calendar month for `range=monthly`).
  final String? axisLabel;

  const AdminStatPoint({
    required this.date,
    required this.count,
    this.axisLabel,
  });
}

class AdminDashboardService {
  AdminDashboardService._();
  static final AdminDashboardService _instance = AdminDashboardService._();
  static AdminDashboardService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...AdminAuthService.instance.authHeaders,
  };

  Future<AdminOverviewStats> fetchOverviewStats() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/stats/overview'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load overview stats');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminOverviewStats.fromJson(data);
  }

  Future<List<AdminStatPoint>> fetchUserGrowth({required String range}) {
    return _fetchSeries('/admin/stats/user-growth', range: range);
  }

  Future<List<AdminStatPoint>> fetchPostFrequency({required String range}) {
    return _fetchSeries('/admin/stats/post-frequency', range: range);
  }

  Future<List<AdminStatPoint>> fetchChatbotInteractions({
    required String range,
  }) {
    return _fetchSeries('/admin/stats/chatbot-interactions', range: range);
  }

  Future<List<AdminStatPoint>> _fetchSeries(
    String endpoint, {
    required String range,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: {'range': range});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load chart data');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (data['data'] as List<dynamic>? ?? const []);
    final points = <AdminStatPoint>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final rawDate = row['date']?.toString();
      final date = rawDate == null ? null : DateTime.tryParse(rawDate);
      if (date == null) continue;
      final rawCount = row['count'];
      final count = rawCount is int
          ? rawCount
          : int.tryParse(rawCount?.toString() ?? '0') ?? 0;
      final rawLabel = row['label']?.toString().trim();
      final axisLabel =
          (rawLabel != null && rawLabel.isNotEmpty) ? rawLabel : null;
      points.add(
        AdminStatPoint(date: date, count: count, axisLabel: axisLabel),
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }
}
