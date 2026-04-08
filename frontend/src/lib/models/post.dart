import '../utils/media_url.dart';

class Post {
  final int id;
  final int? userId;
  final int? recipeId;
  final String userName;
  final String? userProfilePhotoUrl;
  final String content;
  final String imageUrl;
  final String? createdAt;
  final int likesCount;
  final bool isLiked;

  Post({
    required this.id,
    this.userId,
    this.recipeId,
    required this.userName,
    this.userProfilePhotoUrl,
    required this.content,
    required this.imageUrl,
    this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';
    final photo = user?['profile_photo_url'] as String?;

    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      recipeId: json['recipe_id'] as int?,
      userName: userName,
      userProfilePhotoUrl: photo,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  String? get displayImageUrl => resolveStorageDisplayUrl(imageUrl.isEmpty ? null : imageUrl);

  String? get displayAuthorProfilePhotoUrl => resolveStorageDisplayUrl(userProfilePhotoUrl);
}