import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/post.dart';
import '../utils/media_url.dart';
import 'auth_service.dart';

class PostComment {
  final int id;
  final String comment;
  final String userName;
  final String createdAt;
  final String? imageUrl;
  final String? profilePhotoUrl;

  PostComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.createdAt,
    this.imageUrl,
    this.profilePhotoUrl,
  });

  static String? _normalizeImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final value = rawUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    final path = value.startsWith('/') ? value : '/$value';
    return '$base$path';
  }

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? '';
    return PostComment(
      id: json['id'] as int,
      comment: json['comment'] as String? ?? '',
      userName: name,
      createdAt: json['created_at'] as String? ?? '',
      imageUrl: _normalizeImageUrl(json['image_url'] as String?),
      profilePhotoUrl: _normalizeImageUrl(
        user?['profile_photo_url'] as String?,
      ),
    );
  }

  String? get displayProfilePhotoUrl =>
      resolveStorageDisplayUrl(profilePhotoUrl);
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

  /// GET /api/posts/{id} — includes gallery `images` when present.
  Future<Post> fetchPost(int id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to load post');
  }

  Future<PostCommentsResponse> fetchCommentsPaginated(
    int postId, {
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/posts/$postId/comments',
      ).replace(queryParameters: {'page': '$page', 'per_page': '$perPage'});
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return PostCommentsResponse(
          comments: const [],
          currentPage: page,
          lastPage: page,
          total: 0,
          perPage: perPage,
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final paged = data['data'] as List<dynamic>?;
      final legacy = data['comments'] as List<dynamic>?;
      final list = paged ?? legacy ?? <dynamic>[];
      return PostCommentsResponse(
        comments: list
            .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentPage: (data['current_page'] as num?)?.toInt() ?? page,
        lastPage: (data['last_page'] as num?)?.toInt() ?? page,
        total: (data['total'] as num?)?.toInt() ?? list.length,
        perPage: (data['per_page'] as num?)?.toInt() ?? perPage,
      );
    } catch (_) {
      // Network/CORS/timeout errors should not crash the feed UI.
      return PostCommentsResponse(
        comments: const [],
        currentPage: page,
        lastPage: page,
        total: 0,
        perPage: perPage,
      );
    }
  }

  Future<List<PostComment>> fetchComments(int postId) async {
    final res = await fetchCommentsPaginated(postId);
    return res.comments;
  }

  /// Add a comment with optional image attachment.
  Future<PostComment?> addComment(
    int postId,
    String comment, {
    XFile? image,
  }) async {
    // Use multipart so we can attach an image
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/posts/$postId/comments'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      ...AuthService.instance.authHeaders,
    });

    if (comment.trim().isNotEmpty) {
      request.fields['comment'] = comment.trim();
    }

    if (image != null) {
      final bytes = await image.readAsBytes();
      final filename = image.name.isNotEmpty ? image.name : 'image.jpg';
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      final body = response.body;
      String? message;
      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        message = data['message'] as String?;
      } catch (_) {
        // Fall through to generic status error when payload is not JSON.
      }
      if (message != null && message.trim().isNotEmpty) {
        throw Exception(message);
      }
      throw Exception('Failed to add comment (HTTP ${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final c = data['comment'] as Map<String, dynamic>?;
    if (c == null) return null;
    return PostComment.fromJson(c);
  }

  /// PUT /api/posts/{id}
  Future<Post> updatePost(
    int postId, {
    required String content,
    String? title,
    int? recipeId,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/posts/$postId'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        if (title != null) 'title': title,
        if (recipeId != null) 'recipe_id': recipeId,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final postJson = data['post'] as Map<String, dynamic>?;
      if (postJson != null) {
        return Post.fromJson(postJson);
      }
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to update post');
  }

  /// DELETE /api/posts/{id}
  Future<void> deletePost(int postId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/posts/$postId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return;
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to delete post');
  }
}

class PostCommentsResponse {
  final List<PostComment> comments;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const PostCommentsResponse({
    required this.comments,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });
}
