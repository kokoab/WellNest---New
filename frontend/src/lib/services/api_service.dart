import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/post.dart';
import 'auth_service.dart';

class ApiService {
  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...AuthService.instance.authHeaders,
  };

  Future<Post> createPost({
    required String content,
    String? title,
    int? recipeId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/posts'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        if (title != null && title.isNotEmpty) 'title': title,
        if (recipeId != null) 'recipe_id': recipeId,
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final postData = data['post'] as Map<String, dynamic>;
      return Post.fromJson(postData);
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to create post');
  }

  /// Upload one image; returns server-assigned id (for reorder/delete).
  Future<int> uploadPostImage(int postId, XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final name = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/posts/$postId/images'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      ...AuthService.instance.authHeaders,
    });
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: name),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      String? message;
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        message = err['message'] as String?;
        final errors = err['errors'];
        if ((message == null || message.isEmpty) && errors is Map) {
          final firstErrorList = errors.values.cast<dynamic>().firstWhere(
            (value) => value is List && value.isNotEmpty,
            orElse: () => null,
          );
          if (firstErrorList is List && firstErrorList.isNotEmpty) {
            message = firstErrorList.first?.toString();
          }
        }
      } catch (_) {
        // Ignore non-JSON payloads and fallback below.
      }
      throw Exception(
        message ?? 'Failed to upload image (HTTP ${response.statusCode})',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final img = data['image'] as Map<String, dynamic>?;
    final id = img?['id'] as int?;
    if (id != null) return id;
    throw Exception('Invalid upload response');
  }

  Future<void> deletePostImage(int postId, int imageId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/posts/$postId/images/$imageId'),
      headers: _headers,
    );
    if (response.statusCode == 200) return;
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to delete image');
  }

  Future<void> reorderPostImages(int postId, List<int> imageIds) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/posts/$postId/images/reorder'),
      headers: _headers,
      body: jsonEncode({'image_ids': imageIds}),
    );
    if (response.statusCode == 200) return;
    final err = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(err?['message'] as String? ?? 'Failed to reorder images');
  }

  Future<PostListResponse> fetchPostsPaginated({
    int? userId,
    bool followingOnly = false,
    int page = 1,
    int perPage = 10,
    String? search,
    String? sort,
  }) async {
    final queryParameters = <String, String>{};
    if (userId != null) {
      queryParameters['user_id'] = '$userId';
    }
    if (followingOnly) {
      queryParameters['feed'] = 'following';
    }
    queryParameters['page'] = '$page';
    queryParameters['per_page'] = '$perPage';
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (sort != null && sort.trim().isNotEmpty) {
      queryParameters['sort'] = sort.trim();
    }

    final uri = Uri.parse('$_baseUrl/posts').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    try {
      final response = await http.get(
        uri,
        headers: _headers,
      ); // auth headers so backend knows who's logged in
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // Backwards compatible: endpoint may return a plain list or a paginated object with 'data'.
        final list = body is List
            ? body
            : (body is Map<String, dynamic> && body['data'] is List)
            ? body['data'] as List
            : <dynamic>[];
        final posts = list
            .map((dynamic item) => Post.fromJson(item as Map<String, dynamic>))
            .toList();
        if (body is Map<String, dynamic>) {
          final p = _readPostPagination(body, page, perPage);
          return PostListResponse(
            posts: posts,
            currentPage: p.$1,
            lastPage: p.$2,
            total: p.$3,
            perPage: p.$4,
          );
        }
        return PostListResponse(
          posts: posts,
          currentPage: page,
          lastPage: page,
          total: posts.length,
          perPage: perPage,
        );
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to connect to backend: $e");
    }
  }

  /// Reads pagination from Laravel payloads that use either top-level keys or `meta`.
  (int, int, int, int) _readPostPagination(
    Map<String, dynamic> body,
    int fallbackPage,
    int fallbackPerPage,
  ) {
    final meta = body['meta'];
    final m = meta is Map<String, dynamic> ? meta : null;
    int read(String key, int def) {
      final top = body[key];
      if (top is num) return top.toInt();
      final nested = m?[key];
      if (nested is num) return nested.toInt();
      return def;
    }

    return (
      read('current_page', fallbackPage),
      read('last_page', fallbackPage),
      read('total', body['data'] is List ? (body['data'] as List).length : 0),
      read('per_page', fallbackPerPage),
    );
  }

  Future<List<Post>> fetchPosts({
    int? userId,
    bool followingOnly = false,
    int page = 1,
    int perPage = 10,
    String? search,
    String? sort,
  }) async {
    final res = await fetchPostsPaginated(
      userId: userId,
      followingOnly: followingOnly,
      page: page,
      perPage: perPage,
      search: search,
      sort: sort,
    );
    return res.posts;
  }
}

class PostListResponse {
  final List<Post> posts;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const PostListResponse({
    required this.posts,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });
}
