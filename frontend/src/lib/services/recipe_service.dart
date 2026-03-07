import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/recipe.dart';
import 'auth_service.dart';
import 'admin_auth_service.dart';

/// API calls for recipes. List/show are public; create/update/delete require auth.
class RecipeService {
  RecipeService._();
  static final RecipeService _instance = RecipeService._();
  static RecipeService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  /// Headers for read (list/show) — optional auth so public routes work when not logged in.
  Map<String, String> get _headersForRead => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (AuthService.instance.authHeaders.isNotEmpty) ...AuthService.instance.authHeaders,
        if (AuthService.instance.authHeaders.isEmpty && AdminAuthService.instance.authHeaders.isNotEmpty)
          ...AdminAuthService.instance.authHeaders,
      };

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// GET /api/recipes — optional category_id, user_id, search (name/ingredients), paginated (public)
  Future<RecipeListResponse> fetchRecipes({
    int? categoryId,
    int? userId,
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (categoryId != null) params['category_id'] = '$categoryId';
    if (userId != null) params['user_id'] = '$userId';
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    final uri = Uri.parse('$_baseUrl/recipes').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headersForRead);
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

  /// GET /api/recipes/{id} (public)
  Future<Recipe> fetchRecipe(int id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/recipes/$id'),
      headers: _headersForRead,
    );
    if (response.statusCode == 200) {
      return Recipe.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwFromResponse(response);
  }

  /// POST /api/recipes — returns new recipe id for image upload
  Future<int> createRecipe({
    required int categoryId,
    required String title,
    required String instructions,
    required int prepTime,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recipes'),
      headers: _headers,
      body: jsonEncode({
        'category_id': categoryId,
        'title': title.trim(),
        'instructions': instructions.trim(),
        'prep_time': prepTime,
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['id'] as int;
    }
    _throwFromResponse(response);
  }

  /// POST /api/recipes/{id}/images — multipart image upload (auth required).
  /// Uses bytes so it works on web (XFile path is blob URL there).
  Future<void> uploadRecipeImage(int recipeId, XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final name = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/recipes/$recipeId/images'),
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
    if (response.statusCode == 201) return;
    _throwFromResponse(response);
  }

  /// PUT /api/recipes/{id}
  Future<void> updateRecipe(
    int id, {
    int? categoryId,
    String? title,
    String? instructions,
    int? prepTime,
  }) async {
    final body = <String, dynamic>{};
    if (categoryId != null) body['category_id'] = categoryId;
    if (title != null) body['title'] = title.trim();
    if (instructions != null) body['instructions'] = instructions.trim();
    if (prepTime != null) body['prep_time'] = prepTime;
    final response = await http.put(
      Uri.parse('$_baseUrl/recipes/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// DELETE /api/recipes/{id}
  Future<void> deleteRecipe(int id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/recipes/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
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

class RecipeListResponse {
  final List<Recipe> recipes;
  final int currentPage;
  final int lastPage;
  final int total;
  RecipeListResponse({
    required this.recipes,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}
