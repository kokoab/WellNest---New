import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/post.dart';
import 'auth_service.dart';

class ApiService {
  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Future<Post> createPost({
    required String content,
    String? title,
    int? recipeId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      },
      body: jsonEncode({
        'content': content,
        if (title != null && title.isNotEmpty) 'title': title,
        if (recipeId != null) 'recipe_id': recipeId,
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final postData = data['post'] as Map<String, dynamic>;
      return Post.fromJson(postData);
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to create post');
  }

  Future<void> uploadPostImage(int postId, XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final name = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/posts/$postId/images'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      ...AuthService.instance.authHeaders,
    });
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: name,
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      final err = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(err?['message'] as String? ?? 'Failed to upload image');
    }
  }

  Future<List<Post>> fetchPosts({int? userId}) async {
    final uri = Uri.parse('$_baseUrl/posts').replace(
      queryParameters: userId != null ? {'user_id': '$userId'} : null,
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body is List ? body : <dynamic>[];
        return list.map((dynamic item) => Post.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to connect to backend: $e");
    }
  }
}