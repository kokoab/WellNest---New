class Post {
  final int id;
  final String userName;
  final String content;
  final String imageUrl;

  Post({required this.id, required this.userName, required this.content, required this.imageUrl});

  // Factory to convert JSON from Laravel to a Flutter Object
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userName: json['user']['name'], // Assuming Laravel returns nested user
      content: json['content'],
      imageUrl: json['image_url'],
    );
  }
}