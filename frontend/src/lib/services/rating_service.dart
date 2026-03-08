import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/recipe_rating.dart';
import 'auth_service.dart';

/// API calls for recipe ratings and reviews.
class RatingService {
  RatingService._();
  static final RatingService _instance = RatingService._();
  static RatingService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  Map<String, String> get _headersForRead => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (AuthService.instance.authHeaders.isNotEmpty) ...AuthService.instance.authHeaders,
      };

  /// GET /api/recipes/{id}/ratings — list all reviews (public).
  Future<RecipeRatingsResponse> fetchRatings(int recipeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/$recipeId/ratings'),
      headers: _headersForRead,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return RecipeRatingsResponse(
        ratings: list.map((e) => RecipeRating.fromJson(e as Map<String, dynamic>)).toList(),
        averageRating: (data['average_rating'] as num?)?.toDouble() ?? 0,
        ratingsCount: data['ratings_count'] as int? ?? 0,
      );
    }
    _throwFromResponse(response);
  }

  /// GET /api/recipes/{id}/ratings/me — current user's rating (auth required).
  Future<RecipeRating?> fetchUserRating(int recipeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/$recipeId/ratings/me'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final r = data['rating'];
      if (r == null) return null;
      return RecipeRating.fromJson(r as Map<String, dynamic>);
    }
    _throwFromResponse(response);
  }

  /// POST /api/recipes/{id}/ratings — submit or update rating (auth required, one per user).
  Future<RecipeRating> submitRating({
    required int recipeId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': rating};
    if (comment != null && comment.trim().isNotEmpty) body['comment'] = comment.trim();
    final response = await http.post(
      Uri.parse('$_baseUrl/recipes/$recipeId/ratings'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RecipeRating.fromJson(data['rating'] as Map<String, dynamic>);
    }
    _throwFromResponse(response);
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final message = data?['message'] as String?;
    final errors = data?['errors'] as Map<String, dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      final list = first is List ? first : [first];
      final msg = list.isNotEmpty ? list.first.toString() : message;
      throw Exception(msg ?? 'Validation failed');
    }
    throw Exception(message ?? 'Request failed: ${response.statusCode}');
  }
}

class RecipeRatingsResponse {
  final List<RecipeRating> ratings;
  final double averageRating;
  final int ratingsCount;
  RecipeRatingsResponse({
    required this.ratings,
    required this.averageRating,
    required this.ratingsCount,
  });
}
