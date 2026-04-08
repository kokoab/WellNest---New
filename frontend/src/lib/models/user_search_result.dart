import '../utils/media_url.dart';

/// User returned from GET /api/users/search (for starting a chat).
class UserSearchResult {
  final int id;
  final String name;
  final String? profilePhotoUrl;

  UserSearchResult({required this.id, required this.name, this.profilePhotoUrl});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }

  String? get displayProfilePhotoUrl => resolveStorageDisplayUrl(profilePhotoUrl);
}
