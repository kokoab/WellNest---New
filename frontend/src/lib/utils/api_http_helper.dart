import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared HTTP error parsing for API services.
class ApiHttpException implements Exception {
  final String message;
  final int? statusCode;

  const ApiHttpException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

String messageFromApiResponse(http.Response response, String fallback) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
        }
      }
    }
  } catch (_) {
    // Non-JSON body — use fallback.
  }
  return fallback;
}

Never throwFromApiResponse(http.Response response, String fallback) {
  throw ApiHttpException(
    messageFromApiResponse(response, fallback),
    statusCode: response.statusCode,
  );
}
