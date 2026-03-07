class Post {
  final int id;
  final int? userId;
  final int? recipeId;
  final String userName;
  final String content;
  final String imageUrl;

  Post({
    required this.id,
    this.userId,
    this.recipeId,
    required this.userName,
    required this.content,
    required this.imageUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userName = user is Map ? (user['name'] as String? ?? '') : '';
    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      recipeId: json['recipe_id'] as int?,
      userName: userName,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }
}