import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_app/config/app_config.dart';
import 'package:my_app/services/admin_auth_service.dart';

/// Admin-only dashboard counts (posts, recipes, etc.).
class AdminStatsSummary {
  const AdminStatsSummary({required this.postsTotal, required this.recipesTotal});

  final int postsTotal;
  final int recipesTotal;

  factory AdminStatsSummary.fromJson(Map<String, dynamic> json) {
    return AdminStatsSummary(
      postsTotal: (json['posts_total'] as num?)?.toInt() ?? 0,
      recipesTotal: (json['recipes_total'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminStatsService {
  AdminStatsService._();
  static final AdminStatsService _instance = AdminStatsService._();
  static AdminStatsService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AdminAuthService.instance.authHeaders,
      };

  /// GET /api/admin/stats/summary
  Future<AdminStatsSummary> fetchSummary() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/stats/summary'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminStatsSummary.fromJson(data);
    }
    final message = _messageFromBody(response.body);
    throw Exception(message ?? 'Failed to load stats (${response.statusCode})');
  }

  String? _messageFromBody(String body) {
    try {
      final err = jsonDecode(body) as Map<String, dynamic>?;
      return err?['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}
