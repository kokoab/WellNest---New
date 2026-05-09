import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'admin_auth_service.dart';

class NotificationCategory {
  static const String message = 'MESSAGE_TYPE';
  static const String activity = 'ACTIVITY_TYPE';
}

class NotificationCounts {
  final int allUnread;
  final int messageUnread;
  final int activityUnread;

  const NotificationCounts({
    required this.allUnread,
    required this.messageUnread,
    required this.activityUnread,
  });

  factory NotificationCounts.fromResponse(Map<String, dynamic> body) {
    final counts = body['counts'] is Map<String, dynamic>
        ? body['counts'] as Map<String, dynamic>
        : <String, dynamic>{};

    int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

    final message = toInt(
      counts['message_unread'] ?? counts[NotificationCategory.message],
    );
    final activity = toInt(
      counts['activity_unread'] ?? counts[NotificationCategory.activity],
    );
    final all = toInt(counts['all_unread'] ?? body['count']);

    return NotificationCounts(
      allUnread: all == 0 ? (message + activity) : all,
      messageUnread: message,
      activityUnread: activity,
    );
  }
}

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

  Future<NotificationListResponse> fetchNotificationsPaginated({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
    String? category,
  }) async {
    if (!_hasAuth) {
      return NotificationListResponse(
        notifications: const [],
        currentPage: page,
        lastPage: page,
        total: 0,
        perPage: perPage,
      );
    }
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (unreadOnly) 'unread_only': 'true',
      if (category != null && category.isNotEmpty) 'category': category,
    };
    final uri = Uri.parse(
      '$_baseUrl/notifications',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      return NotificationListResponse(
        notifications: const [],
        currentPage: page,
        lastPage: page,
        total: 0,
        perPage: perPage,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>?) ?? [];
    return NotificationListResponse(
      notifications: list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (data['current_page'] as num?)?.toInt() ?? page,
      lastPage: (data['last_page'] as num?)?.toInt() ?? page,
      total: (data['total'] as num?)?.toInt() ?? list.length,
      perPage: (data['per_page'] as num?)?.toInt() ?? perPage,
    );
  }

  Future<List<AppNotification>> fetchNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
    String? category,
  }) async {
    final res = await fetchNotificationsPaginated(
      page: page,
      perPage: perPage,
      unreadOnly: unreadOnly,
      category: category,
    );
    return res.notifications;
  }

  Future<NotificationCounts> getUnreadCounts({String? category}) async {
    if (!_hasAuth) {
      return const NotificationCounts(
        allUnread: 0,
        messageUnread: 0,
        activityUnread: 0,
      );
    }
    final params = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
    };

    final uri = Uri.parse(
      '$_baseUrl/notifications/unread-count',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      return const NotificationCounts(
        allUnread: 0,
        messageUnread: 0,
        activityUnread: 0,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationCounts.fromResponse(data);
  }

  Future<int> getUnreadCount({String? category}) async {
    final counts = await getUnreadCounts(category: category);
    if (category == NotificationCategory.message) return counts.messageUnread;
    if (category == NotificationCategory.activity) return counts.activityUnread;
    return counts.allUnread;
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

class NotificationListResponse {
  final List<AppNotification> notifications;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const NotificationListResponse({
    required this.notifications,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });
}
