import '../utils/json_helpers.dart';

/// Activity log entry for admin (matches backend GET admin/activity-logs item).
class ActivityLog {
  final int id;
  final String? createdAt;
  final String category;
  final String action;
  final String description;
  final String? actorName;
  final String? subjectType;
  final int? subjectId;
  final String? loginType;
  final String? email;
  final String? ipAddress;

  ActivityLog({
    required this.id,
    this.createdAt,
    required this.category,
    required this.action,
    required this.description,
    this.actorName,
    this.subjectType,
    this.subjectId,
    this.loginType,
    this.email,
    this.ipAddress,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    String? name;
    if (user != null) {
      final first = user['first_name'] as String? ?? '';
      final last = user['last_name'] as String? ?? '';
      name = '$first $last'.trim();
      if (name.isEmpty) name = user['email'] as String?;
    }
    return ActivityLog(
      id: jsonDecodeInt(json['id']),
      createdAt: json['created_at'] as String?,
      category: json['category'] as String? ?? '',
      action: json['action'] as String? ?? '',
      description: json['description'] as String? ?? '',
      actorName: name,
      subjectType: json['subject_type'] as String?,
      subjectId: jsonDecodeIntNullable(json['subject_id']),
      loginType: json['login_type'] as String?,
      email: json['email'] as String?,
      ipAddress: json['ip_address'] as String?,
    );
  }
}
