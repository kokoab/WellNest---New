/// Notification model for API response.
class AppNotification {
  final String id;
  final String type;
  final String category;
  final String message;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.message,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final categoryFromApi = json['category'] as String?;
    final resolvedCategory = categoryFromApi ??
        (type == 'new_message' ? 'MESSAGE_TYPE' : 'ACTIVITY_TYPE');

    return AppNotification(
      id: json['id'] as String? ?? '',
      type: type,
      category: resolvedCategory,
      message: json['message'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : <String, dynamic>{},
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
