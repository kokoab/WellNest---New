import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../utils/media_url.dart';
import 'auth_service.dart';

/// Current user model from GET /user.
class CurrentUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String accountStatus;
  final String? profilePhotoUrl;
  final int followersCount;
  final int followingCount;

  CurrentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.accountStatus = 'active',
    this.profilePhotoUrl,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  String get displayName => '$firstName $lastName'.trim();

  bool get isActiveAccount => accountStatus == 'active';

  /// Profile image URL for display. Uses frontend base URL to fix Docker internal host issues.
  String? get displayProfilePhotoUrl =>
      resolveStorageDisplayUrl(profilePhotoUrl);

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    int count(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : idRaw is num
        ? idRaw.toInt()
        : int.tryParse(idRaw?.toString() ?? '');
    if (id == null) {
      throw FormatException('CurrentUser JSON missing or invalid id');
    }

    return CurrentUser(
      id: id,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accountStatus: json['account_status'] as String? ?? 'active',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      followersCount: count(json['followers_count']),
      followingCount: count(json['following_count']),
    );
  }
}

class PublicUserProfile {
  final int id;
  final String firstName;
  final String lastName;
  final String name;
  final String accountStatus;
  final String? profilePhotoUrl;
  final int followersCount;
  final int followingCount;
  final bool? isFollowing;
  final bool isAvailable;
  final String? availabilityMessage;

  const PublicUserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    this.accountStatus = 'active',
    this.profilePhotoUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing,
    this.isAvailable = true,
    this.availabilityMessage,
  });

  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : '$firstName $lastName'.trim();

  bool get isActiveAccount => accountStatus == 'active';

  String? get displayProfilePhotoUrl =>
      resolveStorageDisplayUrl(profilePhotoUrl);

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      accountStatus: json['account_status'] as String? ?? 'active',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool?,
      isAvailable: json['is_available'] as bool? ?? true,
      availabilityMessage: json['availability_message'] as String?,
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
        final user = CurrentUser.fromJson(data);
        AuthService.instance.setUserId(user.id);
        return user;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PublicUserProfile> fetchPublicProfile(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicUserProfile.fromJson(data);
    }

    throw Exception('Failed to load profile');
  }

  Future<PublicUserProfile> followUser(int userId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/follow'),
      headers: _headers,
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicUserProfile.fromJson(data['user'] as Map<String, dynamic>);
    }

    throw Exception(
      _messageFromResponse(response, fallback: 'Failed to follow user'),
    );
  }

  Future<PublicUserProfile> unfollowUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$userId/follow'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicUserProfile.fromJson(data['user'] as Map<String, dynamic>);
    }

    throw Exception(
      _messageFromResponse(response, fallback: 'Failed to unfollow user'),
    );
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
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: name),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      final err = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(
        err?['message'] as String? ?? 'Failed to upload profile photo',
      );
    }
  }

  /// PATCH /api/me/deactivate — user deactivates their own account.
  Future<void> deactivateAccount() async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/me/deactivate'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      _messageFromResponse(response, fallback: 'Failed to deactivate account'),
    );
  }

  String _messageFromResponse(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final err = jsonDecode(response.body) as Map<String, dynamic>?;
      return err?['message'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// PATCH /api/user — update current user profile (firstName, lastName, email).
  Future<CurrentUser> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    String? password,
  }) async {
    final payload = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
    };
    final normalizedPassword = password?.trim() ?? '';
    if (normalizedPassword.isNotEmpty) {
      payload['password'] = normalizedPassword;
    }

    final response = await http.patch(
      Uri.parse('$_baseUrl/user'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = (data['user'] is Map<String, dynamic>)
          ? data['user'] as Map<String, dynamic>
          : data;
      return CurrentUser.fromJson(payload);
    }
    throw Exception(_messageFromResponse(response, fallback: 'Failed to update profile'));
  }
}
