import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/meal_plan.dart';
import '../utils/api_http_helper.dart';
import 'auth_service.dart';

/// Plans for a week plus optional per-meal and whole-day skip markers from the API.
class MealPlanWeekData {
  const MealPlanWeekData({
    required this.plans,
    required this.skippedMealKeys,
    required this.skippedDayDates,
  });

  final List<MealPlan> plans;
  final Set<String> skippedMealKeys;
  final Set<String> skippedDayDates;
}

class MealPlanService {
  MealPlanService._();
  static final MealPlanService _instance = MealPlanService._();
  static MealPlanService get instance => _instance;
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...AuthService.instance.authHeaders,
  };

  /// GET /api/meal-plans?week_start=YYYY-MM-DD
  Future<MealPlanWeekData> fetchForWeek(DateTime weekStart) async {
    final dateStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(
      '$_baseUrl/meal-plans',
    ).replace(queryParameters: {'week_start': dateStr});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];
      final plans = list
          .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      final skippedMeals = <String>{};
      final rawMeals = data['skipped_meals'] as List<dynamic>?;
      if (rawMeals != null) {
        for (final e in rawMeals) {
          if (e is! Map<String, dynamic>) continue;
          final date = e['planned_date'];
          final slot = e['meal_slot'];
          if (date is String && slot is String) {
            skippedMeals.add(mealSkipKey(date, slot));
          }
        }
      }
      final skippedDays = <String>{};
      final rawDays = data['skipped_dates'] as List<dynamic>?;
      if (rawDays != null) {
        for (final d in rawDays) {
          if (d is String && d.isNotEmpty) skippedDays.add(d);
        }
      }
      return MealPlanWeekData(
        plans: plans,
        skippedMealKeys: skippedMeals,
        skippedDayDates: skippedDays,
      );
    }
    throwFromApiResponse(response, 'Failed to load meal plans');
  }

  /// POST /api/meal-plans/day-skip — mark entire day as didn't eat.
  Future<void> setDaySkip({
    required DateTime plannedDate,
    required bool didNotEat,
  }) async {
    final dateStr =
        '${plannedDate.year}-${plannedDate.month.toString().padLeft(2, '0')}-${plannedDate.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$_baseUrl/meal-plans/day-skip'),
      headers: _headers,
      body: jsonEncode({
        'planned_date': dateStr,
        'did_not_eat': didNotEat,
      }),
    );
    if (response.statusCode == 200) {
      _notifyChanged();
      return;
    }
    throwFromApiResponse(response, 'Failed to update day skip');
  }

  static String mealSkipKey(String isoDate, String mealSlot) =>
      '$isoDate::$mealSlot';

  /// POST /api/meal-plans/meal-skip
  Future<void> setMealSkip({
    required DateTime plannedDate,
    required String mealSlot,
    required bool skipped,
  }) async {
    final dateStr =
        '${plannedDate.year}-${plannedDate.month.toString().padLeft(2, '0')}-${plannedDate.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$_baseUrl/meal-plans/meal-skip'),
      headers: _headers,
      body: jsonEncode({
        'planned_date': dateStr,
        'meal_slot': mealSlot,
        'skipped': skipped,
      }),
    );
    if (response.statusCode == 200) {
      _notifyChanged();
      return;
    }
    throwFromApiResponse(response, 'Failed to set meal skip');
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
      final plan = MealPlan.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      _notifyChanged();
      return plan;
    }
    throwFromApiResponse(response, 'Failed to create meal plan');
  }

  /// DELETE /api/meal-plans/{id}
  Future<void> delete(int mealPlanId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/meal-plans/$mealPlanId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      _notifyChanged();
      return;
    }
    throwFromApiResponse(response, 'Failed to delete meal plan');
  }

  /// GET /api/meal-plans/export?week_start=YYYY-MM-DD
  Future<MealPlanExport> fetchExportData(DateTime weekStart) async {
    final dateStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(
      '$_baseUrl/meal-plans/export',
    ).replace(queryParameters: {'week_start': dateStr});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return MealPlanExport.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throwFromApiResponse(response, 'Failed to export meal plan');
  }

  static void _notifyChanged() => changes.value++;
}
