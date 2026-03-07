import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class PostComment {
  final int id;
  final String comment;
  final String userName;
  final String createdAt;

  PostComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final name = user is Map ? (user['name'] as String? ?? '') : '';
    return PostComment(
      id: json['id'] as int,
      comment: json['comment'] as String? ?? '',
      userName: name,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class PostService {
  PostService._();
  static final PostService _instance = PostService._();
  static PostService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  Future<List<PostComment>> fetchComments(int postId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$postId/comments'),
      headers: _headers,
    );
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['comments'] as List<dynamic>?) ?? [];
    return list.map((e) => PostComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PostComment?> addComment(int postId, String comment) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/comments'),
      headers: _headers,
      body: jsonEncode({'comment': comment.trim()}),
    );
    if (response.statusCode != 201) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final c = data['comment'] as Map<String, dynamic>?;
    if (c == null) return null;
    return PostComment.fromJson(c);
  }
}
