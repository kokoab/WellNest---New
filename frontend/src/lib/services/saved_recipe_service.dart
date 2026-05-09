import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/recipe.dart';
import 'auth_service.dart';
import 'recipe_service.dart';

/// API calls for saved/favorite recipes. Requires auth.
class SavedRecipeService {
  SavedRecipeService._();
  static final SavedRecipeService _instance = SavedRecipeService._();
  static SavedRecipeService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// POST /api/recipes/{id}/save
  Future<void> saveRecipe(int recipeId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recipes/$recipeId/save'),
      headers: _headers,
    );
    if (response.statusCode == 201) return;
    _throwFromResponse(response);
  }

  /// DELETE /api/recipes/{id}/save
  Future<void> unsaveRecipe(int recipeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/recipes/$recipeId/save'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// GET /api/recipes/{id}/saved
  Future<bool> isSaved(int recipeId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/$recipeId/saved'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['saved'] as bool? ?? false;
    }
    return false;
  }

  /// Paginates all saved recipes to collect their IDs into a [Set].
  Future<Set<int>> fetchAllSavedRecipeIds() async {
    final ids = <int>{};
    int page = 1;
    int lastPage = 1;
    do {
      final resp = await fetchSavedRecipes(page: page);
      for (final r in resp.recipes) {
        ids.add(r.id);
      }
      lastPage = resp.lastPage;
      page++;
    } while (page <= lastPage);
    return ids;
  }

  /// GET /api/saved-recipes — paginated list
  Future<RecipeListResponse> fetchSavedRecipes({
    int page = 1,
    int perPage = 15,
    String? search,
    String? sort,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (sort != null && sort.trim().isNotEmpty) {
      params['sort'] = sort.trim();
    }
    final uri = Uri.parse('$_baseUrl/saved-recipes').replace(
      queryParameters: params,
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return RecipeListResponse(
        recipes: list.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList(),
        currentPage: data['current_page'] as int? ?? 1,
        lastPage: data['last_page'] as int? ?? 1,
        total: data['total'] as int? ?? 0,
      );
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
