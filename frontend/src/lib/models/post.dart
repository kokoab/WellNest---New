import '../utils/media_url.dart';

class Post {
  final int id;
  final int? userId;
  final int? recipeId;
  final String userName;
  final String content;
  final String imageUrl;
  final String? userProfilePhotoUrl;
  final String? createdAt;

  Post({
    required this.id,
    this.userId,
    this.recipeId,
    required this.userName,
    required this.content,
    required this.imageUrl,
    this.userProfilePhotoUrl,
    this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userName = user is Map ? (user['name'] as String? ?? '') : '';
    final photo = user is Map ? user['profile_photo_url'] as String? : null;
    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      recipeId: json['recipe_id'] as int?,
      userName: userName,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      userProfilePhotoUrl: photo,
      createdAt: json['created_at'] as String?,
    );
  }

  String? get displayImageUrl => resolveStorageDisplayUrl(imageUrl.isEmpty ? null : imageUrl);

  String? get displayAuthorProfilePhotoUrl => resolveStorageDisplayUrl(userProfilePhotoUrl);
}