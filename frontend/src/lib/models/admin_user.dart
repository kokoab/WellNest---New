import '../utils/json_helpers.dart';

/// User model for admin list (id, name, email, status).
class AdminUser {
  final int id;
  final String name;
  final String email;
  final String status; // 'active' | 'inactive'
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
      status: json['status'] ?? 'active',
      totalPosts: json['total_posts'] as int? ?? 0,
      lastLogin: json['last_login'] as String?,
    );
  }

  bool get isActive => status == 'active';

  String get statusLabel => isActive ? 'Active' : 'Deactivated';
}
