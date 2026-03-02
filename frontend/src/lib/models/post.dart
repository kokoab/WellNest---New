class Post {
  final int id;
  final String userName;
  final String content;
  final String imageUrl;

  Post({required this.id, required this.userName, required this.content, required this.imageUrl});

  // Factory to convert JSON from Laravel to a Flutter Object
  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userName = user is Map ? (user['name'] as String? ?? '') : '';
    return Post(
      id: json['id'] as int,
      userName: userName,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }
}