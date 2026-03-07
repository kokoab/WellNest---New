import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class ReportService {
  ReportService._();
  static final ReportService _instance = ReportService._();
  static ReportService get instance => _instance;

  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  Future<void> reportRecipe(int recipeId, {String? reason, String? details}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recipes/$recipeId/report'),
      headers: _headers,
      body: jsonEncode({
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      }),
    );
    if (response.statusCode != 201) {
      _throwFromResponse(response);
    }
  }

  Future<void> reportPost(int postId, {String? reason, String? details}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/report'),
      headers: _headers,
      body: jsonEncode({
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      }),
    );
    if (response.statusCode != 201) {
      _throwFromResponse(response);
    }
  }

  static Never _throwFromResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(data?['message'] as String? ?? 'Request failed');
  }
}
