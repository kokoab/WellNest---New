import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Current user model from GET /user.
class CurrentUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePhotoUrl;

  CurrentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePhotoUrl,
  });

  String get displayName => '${firstName} ${lastName}'.trim();

  /// Profile image URL for display. Uses frontend base URL to fix Docker internal host issues.
  String? get displayProfilePhotoUrl {
    if (profilePhotoUrl == null || profilePhotoUrl!.isEmpty) return null;
    final url = profilePhotoUrl!;
    final base = AppConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
    if (url.startsWith('http')) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.path.startsWith('/storage/')) {
        return '$base${uri.path}';
      }
    }
    if (url.startsWith('/')) return base + url;
    return url;
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }
}

class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  static UserService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// GET /api/user — returns current authenticated user.
  Future<CurrentUser?> fetchCurrentUser() async {
    if (!AuthService.instance.isLoggedIn) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CurrentUser.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/user/profile-photo — upload profile photo (auth required).
  Future<void> uploadProfilePhoto(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final name = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/user/profile-photo'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      ...AuthService.instance.authHeaders,
    });
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: name,
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      final err = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(err?['message'] as String? ?? 'Failed to upload profile photo');
    }
  }
}
