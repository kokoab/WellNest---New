import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import 'content_update_notifier.dart';

class VoteService {
  VoteService._();
  static final VoteService _instance = VoteService._();
  static VoteService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  Future<void> likeRecipe(int recipeId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recipes/$recipeId/like'),
      headers: _headers,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      _throwFromResponse(response);
    }
    ContentUpdateNotifier.instance.publish(
      ContentUpdate(
        kind: ContentUpdateKind.recipe,
        action: ContentUpdateAction.likeChanged,
        id: recipeId,
        isActive: true,
      ),
    );
  }

  Future<void> unlikeRecipe(int recipeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/recipes/$recipeId/like'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      _throwFromResponse(response);
    }
    ContentUpdateNotifier.instance.publish(
      ContentUpdate(
        kind: ContentUpdateKind.recipe,
        action: ContentUpdateAction.likeChanged,
        id: recipeId,
        isActive: false,
      ),
    );
  }

  Future<void> likePost(int postId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/like'),
      headers: _headers,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      _throwFromResponse(response);
    }
    ContentUpdateNotifier.instance.publish(
      ContentUpdate(
        kind: ContentUpdateKind.post,
        action: ContentUpdateAction.likeChanged,
        id: postId,
        isActive: true,
      ),
    );
  }

  Future<void> unlikePost(int postId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/posts/$postId/like'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      _throwFromResponse(response);
    }
    ContentUpdateNotifier.instance.publish(
      ContentUpdate(
        kind: ContentUpdateKind.post,
        action: ContentUpdateAction.likeChanged,
        id: postId,
        isActive: false,
      ),
    );
  }

  /// Returns how many likes a post has and whether the current user liked it.
  Future<({int count, bool isLiked})> fetchPostLikes(int postId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$postId/likes'),
      headers: _headers,
    );
    if (response.statusCode != 200) return (count: 0, isLiked: false);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final count = data['likes_count'] as int? ?? data['count'] as int? ?? 0;
    final isLiked = data['is_liked'] as bool? ?? false;
    return (count: count, isLiked: isLiked);
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(data?['message'] as String? ?? 'Request failed');
  }
}