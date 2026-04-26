import '../utils/json_helpers.dart';

/// User model for admin list (id, name, email, account status).
class AdminUser {
  final int id;
  final String name;
  final String email;
  final String status; // 'active' | 'deactivated' | 'suspended'

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: jsonDecodeInt(json['id']),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      status: json['account_status'] ?? json['status'] ?? 'active',
    );
  }

  bool get isActive => status == 'active';

  bool get isSuspended => status == 'suspended';

  bool get isDeactivated => status == 'deactivated';

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'deactivated':
        return 'Deactivated';
      default:
        return status;
    }
  }
}
