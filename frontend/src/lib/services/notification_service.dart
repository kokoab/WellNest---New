import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'admin_auth_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (AuthService.instance.authHeaders.isNotEmpty) {
      h.addAll(AuthService.instance.authHeaders);
    } else if (AdminAuthService.instance.authHeaders.isNotEmpty) {
      h.addAll(AdminAuthService.instance.authHeaders);
    }
    return h;
  }

  bool get _hasAuth =>
      AuthService.instance.authHeaders.isNotEmpty ||
      AdminAuthService.instance.authHeaders.isNotEmpty;

  Future<List<AppNotification>> fetchNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    if (!_hasAuth) return [];
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (unreadOnly) 'unread_only': 'true',
    };
    final uri = Uri.parse('$_baseUrl/notifications').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>?) ?? [];
    return list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> getUnreadCount() async {
    if (!_hasAuth) return 0;
    final response = await http.get(
      Uri.parse('$_baseUrl/notifications/unread-count'),
      headers: _headers,
    );
    if (response.statusCode != 200) return 0;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(String id) async {
    if (!_hasAuth) return;
    await http.patch(
      Uri.parse('$_baseUrl/notifications/$id/read'),
      headers: _headers,
    );
  }

  Future<void> markAllAsRead() async {
    if (!_hasAuth) return;
    await http.post(
      Uri.parse('$_baseUrl/notifications/read-all'),
      headers: _headers,
    );
  }
}
