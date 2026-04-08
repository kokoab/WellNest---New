import '../utils/json_helpers.dart';

/// User model for admin list (id, name, email, status).
class AdminUser {
  final int id;
  final String name;
  final String email;
  final String status; // 'active' | 'inactive'

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
      status: json['status'] ?? 'active',
    );
  }

  bool get isActive => status == 'active';

  String get statusLabel => isActive ? 'Active' : 'Deactivated';
}
