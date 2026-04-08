import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../utils/media_url.dart';
import 'auth_service.dart';

class PostComment {
  final int id;
  final String comment;
  final String userName;
  final String createdAt;
  final String? imageUrl;

  PostComment({
    required this.id,
    required this.comment,
    required this.userName,
    required this.createdAt,
    this.imageUrl,
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
    final user = json['user'];
    final name = user is Map ? (user['name'] as String? ?? '') : '';
    return PostComment(
      id: json['id'] as int,
      comment: json['comment'] as String? ?? '',
      userName: name,
      createdAt: json['created_at'] as String? ?? '',
      imageUrl: _normalizeImageUrl(json['image_url'] as String?),
    );
  }

  String? get displayProfilePhotoUrl => resolveStorageDisplayUrl(profilePhotoUrl);
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
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/posts/$postId/comments'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['comments'] as List<dynamic>?) ?? [];
      return list.map((e) => PostComment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // Network/CORS/timeout errors should not crash the feed UI.
      return [];
    }
  }

  /// Add a comment with optional image attachment.
  Future<PostComment?> addComment(int postId, String comment, {XFile? image}) async {
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
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      ));
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
}