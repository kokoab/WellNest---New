import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

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
  }

  Future<void> unlikeRecipe(int recipeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/recipes/$recipeId/like'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      _throwFromResponse(response);
    }
  }

  Future<void> likePost(int postId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/like'),
      headers: _headers,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      _throwFromResponse(response);
    }
  }

  Future<void> unlikePost(int postId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/posts/$postId/like'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      _throwFromResponse(response);
    }
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(data?['message'] as String? ?? 'Request failed');
  }
}
