import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../models/conversation_list_item.dart';
import '../models/user_search_result.dart';
import 'auth_service.dart';
import 'reverb_service.dart';

class ConversationService {
  static String get _baseUrl => '${AppConfig.baseUrl}/api';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthService.instance.authHeaders,
      };

  /// GET /api/users/search?q=... — search users to message (excludes current user).
  Future<List<UserSearchResult>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/users/search').replace(queryParameters: {'q': query.trim()});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['message'] as String? ?? 'Search failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final list = data?['data'] as List<dynamic>? ?? [];
    return list.map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/conversations — get or create conversation with another user. Returns conversation (with id).
  Future<ConversationListItem> createConversation(int otherUserId, String otherUserName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/conversations'),
      headers: _headers,
      body: jsonEncode({'user_id': otherUserId}),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['message'] as String? ?? 'Failed to start conversation');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final other = data['other_user'] is Map<String, dynamic>
        ? ConversationOtherUser.fromJson(data['other_user'] as Map<String, dynamic>)
        : ConversationOtherUser(id: otherUserId, name: otherUserName);
    return ConversationListItem(
      id: (data['id'] as num).toInt(),
      otherUser: other,
      lastMessage: null,
      unreadCount: 0,
      lastMessageAt: null,
    );
  }

  /// GET /api/conversations — list conversations (Messenger-style).
  Future<List<ConversationListItem>> fetchConversations() async {
    final response = await http.get(Uri.parse('$_baseUrl/conversations'), headers: _headers);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['message'] as String? ?? 'Failed to load conversations');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final list = data?['data'] as List<dynamic>? ?? [];
    return list.map((e) => ConversationListItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/conversations/{id}/messages — messages for one conversation (paginated).
  Future<Map<String, dynamic>> fetchMessages(int conversationId, {int page = 1, int perPage = 20}) async {
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId/messages').replace(
      queryParameters: {'page': '$page', 'per_page': '$perPage'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['message'] as String? ?? 'Failed to load messages');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Parse messages from API paginated response.
  static List<ChatMessage> messagesFromResponse(Map<String, dynamic> data) {
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/conversations/{id}/messages — send a message. Backend will broadcast via Reverb.
  Future<ChatMessage> sendMessage(int conversationId, String content) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['message'] as String? ?? 'Failed to send message');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatMessage.fromJson(data);
  }

  /// POST /api/messages/{messageId}/attachments — upload image (or file) for an existing message.
  Future<Map<String, dynamic>> uploadMessageAttachment(int messageId, List<int> fileBytes, String fileName) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/messages/$messageId/attachments'),
    );
    request.headers.addAll({'Accept': 'application/json', ...AuthService.instance.authHeaders});
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName.isNotEmpty ? fileName : 'image.jpg',
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['message'] as String? ?? 'Failed to upload attachment');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Subscribe to live new messages for a conversation. Call when opening the chat.
  /// [onNewMessage] receives the message payload (use ChatMessage.fromJson(payload['message']) if backend sends { message: {... } }).
  Future<void> subscribeToLiveMessages(int conversationId, void Function(ChatMessage message) onNewMessage) async {
    await ReverbService.instance.subscribeToConversation(conversationId, (payload) {
      final messageMap = _extractMessageMap(payload);
      if (messageMap != null) {
        onNewMessage(ChatMessage.fromJson(messageMap));
      }
    });
  }

  Map<String, dynamic>? _extractMessageMap(Map<String, dynamic> payload) {
    dynamic candidate = payload['message'] ?? payload;

    // Some transports nest again in a "data" field.
    if (candidate is Map && candidate['message'] != null) {
      candidate = candidate['message'];
    } else if (candidate is Map && candidate['data'] != null) {
      candidate = candidate['data'];
    }

    if (candidate is! Map) return null;
    final map = Map<String, dynamic>.from(candidate);
    // Minimal shape guard to avoid parsing unrelated events.
    if (!map.containsKey('id') || !map.containsKey('conversation_id')) {
      return null;
    }
    return map;
  }

  /// Unsubscribe when leaving the chat screen.
  Future<void> unsubscribeFromLiveMessages(int conversationId) async {
    await ReverbService.instance.unsubscribeFromConversation(conversationId);
  }

  /// Mark all messages in a conversation as read.
  Future<void> markConversationAsRead(int conversationId) async {
    await http.patch(
      Uri.parse('$_baseUrl/conversations/$conversationId/messages/read'),
      headers: _headers,
    );
  }
}
