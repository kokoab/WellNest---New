import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/meal_plan.dart';
import 'auth_service.dart';

class MealPlanService {
  MealPlanService._();
  static final MealPlanService _instance = MealPlanService._();
  static MealPlanService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// GET /api/meal-plans?week_start=YYYY-MM-DD
  Future<List<MealPlan>> fetchForWeek(DateTime weekStart) async {
    final dateStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_baseUrl/meal-plans')
        .replace(queryParameters: {'week_start': dateStr});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _throwFromResponse(response);
  }

  /// POST /api/meal-plans
  Future<MealPlan> create({
    required int recipeId,
    required DateTime plannedDate,
    String mealSlot = 'dinner',
  }) async {
    final dateStr =
        '${plannedDate.year}-${plannedDate.month.toString().padLeft(2, '0')}-${plannedDate.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$_baseUrl/meal-plans'),
      headers: _headers,
      body: jsonEncode({
        'recipe_id': recipeId,
        'planned_date': dateStr,
        'meal_slot': mealSlot,
      }),
    );
    if (response.statusCode == 201) {
      return MealPlan.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwFromResponse(response);
  }

  /// DELETE /api/meal-plans/{id}
  Future<void> delete(int mealPlanId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/meal-plans/$mealPlanId'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    _throwFromResponse(response);
  }

  /// GET /api/meal-plans/export?week_start=YYYY-MM-DD
  Future<MealPlanExport> fetchExportData(DateTime weekStart) async {
    final dateStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_baseUrl/meal-plans/export')
        .replace(queryParameters: {'week_start': dateStr});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return MealPlanExport.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throwFromResponse(response);
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final message = data?['message'] as String?;
    throw Exception(message ?? 'Request failed: ${response.statusCode}');
  }
}
