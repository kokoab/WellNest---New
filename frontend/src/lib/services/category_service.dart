import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/category.dart';
import 'auth_service.dart';
import 'admin_auth_service.dart';

/// API calls for categories. GET uses auth; admin create/update/delete require admin.
class CategoryService {
  CategoryService._();
  static final CategoryService _instance = CategoryService._();
  static CategoryService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> _headers({required bool admin}) {
    final auth = admin
        ? AdminAuthService.instance.authHeaders
        : (AuthService.instance.authHeaders.isNotEmpty
              ? AuthService.instance.authHeaders
              : AdminAuthService.instance.authHeaders);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...auth,
    };
  }

  /// GET /api/categories — list (auth required). Use admin: true when called from admin dashboard.
  Future<List<Category>> fetchCategories({bool admin = false}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/categories'),
      headers: _headers(admin: admin),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _throwFromResponse(response);
  }

  /// GET /api/categories/{id}
  Future<Category> fetchCategory(int id, {bool admin = false}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/categories/$id'),
      headers: _headers(admin: admin),
    );
    if (response.statusCode == 200) {
      return Category.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    _throwFromResponse(response);
  }

  /// POST /api/categories — admin only
  Future<Category> createCategory(String name, String description) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/categories'),
      headers: _headers(admin: true),
      body: jsonEncode({
        'name': name.trim(),
        'description': description.trim(),
      }),
    );
    if (response.statusCode == 201) {
      return Category.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    _throwFromResponse(response);
  }

  /// POST /api/categories/for-recipe — regular authenticated users can create
  /// recipe categories while authoring a recipe.
  Future<Category> findOrCreateForRecipe(String name) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/categories/for-recipe'),
      headers: _headers(admin: false),
      body: jsonEncode({
        'name': name.trim(),
        'description': 'User-created recipe category.',
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Category.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    _throwFromResponse(response);
  }

  /// PUT /api/categories/{id} — admin only
  Future<Category> updateCategory(
    int id,
    String name,
    String description,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/categories/$id'),
      headers: _headers(admin: true),
      body: jsonEncode({
        'name': name.trim(),
        'description': description.trim(),
      }),
    );
    if (response.statusCode == 200) {
      return Category.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    _throwFromResponse(response);
  }

  /// DELETE /api/categories/{id} — admin only
  Future<void> deleteCategory(int id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/categories/$id'),
      headers: _headers(admin: true),
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
