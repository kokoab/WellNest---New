import '../utils/json_helpers.dart';

/// User model for admin list (id, name, email, account status).
class AdminUser {
  final int id;
  final String name;
  final String email;
  final String status; // 'active' | 'deactivated' | 'suspended'
  final int totalPosts;
  final String? lastLogin;


  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.totalPosts = 0,
    this.lastLogin,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: jsonDecodeInt(json['id']),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
<<<<<<< HEAD
      status: json['status'] ?? 'active',
      totalPosts: json['total_posts'] as int? ?? 0,
      lastLogin: json['last_login'] as String?,
=======
      status: json['account_status'] ?? json['status'] ?? 'active',
>>>>>>> 486aa5bd074b999d4be69f0b20e5ef0216252935
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
