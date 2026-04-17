import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class MealPlannerService {
  MealPlannerService._();

  static final MealPlannerService _instance = MealPlannerService._();
  static MealPlannerService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  Future<bool> logAssignment({
    required DateTime day,
    required DateTime weekStart,
    required int? recipeId,
    String? recipeTitle,
  }) async {
    if (!AuthService.instance.isLoggedIn) {
      debugPrint('MealPlanner log skipped: user is not authenticated.');
      return false;
    }

    final action = recipeId == null ? 'clear_day' : 'assign_recipe';
    final payload = <String, dynamic>{
      'action': action,
      'day': _dateOnly(day),
      'week_start': _dateOnly(weekStart),
      'recipe_id': recipeId,
      'recipe_title': recipeTitle,
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/meal-planner/log'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201) {
        return true;
      }
      debugPrint(
        'MealPlanner log failed: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (_) {
      debugPrint('MealPlanner log failed: network error while posting.');
      return false;
    }
  }

  static String _dateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
