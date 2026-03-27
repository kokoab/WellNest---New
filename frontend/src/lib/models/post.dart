import '../config/app_config.dart';

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

  static String? _normalizeImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final value = rawUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.path.startsWith('/storage/')) {
        final base = AppConfig.baseUrl.endsWith('/')
            ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
            : AppConfig.baseUrl;
        return '$base${uri.path}';
      }
      return value;
    }
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    final path = value.startsWith('/') ? value : '/$value';
    return '$base$path';
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userName = user is Map ? (user['name'] as String? ?? '') : '';
    final profilePhotoUrl = user is Map ? (user['profile_photo_url'] as String?) : null;
    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      recipeId: json['recipe_id'] as int?,
      userName: userName,
      userProfilePhotoUrl: _normalizeImageUrl(profilePhotoUrl),
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }
}