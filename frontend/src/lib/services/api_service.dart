import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart'; // Import your config
import '../models/post.dart';

class ApiService {
  // Use the baseUrl from your AppConfig
  final String _url = "${AppConfig.baseUrl}/api/posts";

  Future<List<Post>> fetchPosts() async {
    try {
      final response = await http.get(Uri.parse(_url));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        // Map the JSON list to a List of Post objects
        return body.map((dynamic item) => Post.fromJson(item)).toList();
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to connect to backend: $e");
    }
  }
}