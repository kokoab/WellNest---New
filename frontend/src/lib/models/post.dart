import '../utils/media_url.dart';

/// One image attached to a post (gallery); ordered by [sortOrder].
class PostGalleryImage {
  final int id;
  final int sortOrder;
  final String url;

  PostGalleryImage({
    required this.id,
    required this.sortOrder,
    required this.url,
  });

  factory PostGalleryImage.fromJson(Map<String, dynamic> json) {
    return PostGalleryImage(
      id: json['id'] as int,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
    );
  }

  String? get displayUrl => resolveStorageDisplayUrl(url.isEmpty ? null : url);
}

class Post {
  final int id;
  final int? userId;
  final int? recipeId;
  final String? title;
  final String userName;
  final String? userProfilePhotoUrl;
  final String content;
  final String imageUrl;
  final List<PostGalleryImage> galleryImages;
  final String? createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;

  Post({
    required this.id,
    this.userId,
    this.recipeId,
    this.title,
    required this.userName,
    this.userProfilePhotoUrl,
    required this.content,
    required this.imageUrl,
    this.galleryImages = const [],
    this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';
    final photo = user?['profile_photo_url'] as String?;

    List<PostGalleryImage> gallery = const [];
    final rawGallery = json['images'] as List<dynamic>?;
    if (rawGallery != null && rawGallery.isNotEmpty) {
      gallery = rawGallery
          .map(
            (e) => PostGalleryImage.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    }

    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      recipeId: json['recipe_id'] as int?,
      title: json['title'] as String?,
      userName: userName,
      userProfilePhotoUrl: photo,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      galleryImages: gallery,
      createdAt: json['created_at'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  String? get displayImageUrl =>
      resolveStorageDisplayUrl(imageUrl.isEmpty ? null : imageUrl);

  /// URLs for detail gallery (prefers API `images`; falls back to legacy `image_url`).
  List<String> get galleryDisplayUrls {
    if (galleryImages.isNotEmpty) {
      return galleryImages
          .map((e) => e.displayUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();
    }
    final u = displayImageUrl;
    if (u != null && u.isNotEmpty) return [u];
    return [];
  }

  String? get displayAuthorProfilePhotoUrl =>
      resolveStorageDisplayUrl(userProfilePhotoUrl);
}
