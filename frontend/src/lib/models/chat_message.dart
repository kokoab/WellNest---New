import 'dart:convert';

import '../utils/media_url.dart';

/// DB-backed recipe link attached to an assistant message (from [metadata]).
class ChatRecipeSuggestion {
  final int id;
  final String title;

  ChatRecipeSuggestion({required this.id, required this.title});

  factory ChatRecipeSuggestion.fromJson(Map<String, dynamic> json) {
    final t = json['title'] as String?;
    return ChatRecipeSuggestion(
      id: (json['id'] as num).toInt(),
      title: (t != null && t.trim().isNotEmpty) ? t.trim() : 'Recipe',
    );
  }
}

/// A single message in a conversation (from API or Reverb).
class ChatMessage {
  final int id;
  final int conversationId;
  final int userId;
  final String content;
  final String? readAt;
  final String createdAt;
  final ChatMessageUser? user;
  final List<Map<String, dynamic>> attachments;
  final List<ChatRecipeSuggestion> recipeSuggestions;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.content,
    this.readAt,
    required this.createdAt,
    this.user,
    List<Map<String, dynamic>>? attachments,
    List<ChatRecipeSuggestion>? recipeSuggestions,
  }) : attachments = attachments ?? [],
       recipeSuggestions = recipeSuggestions ?? const [];

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final metaMap = _normalizeMetadata(json['metadata']);
    final directRecipeSuggestions = _recipeSuggestionsFromRaw(
      json['recipe_suggestions'],
    );

    Map<String, dynamic>? userMap;
    if (json['user'] is Map<String, dynamic>) {
      userMap = json['user'] as Map<String, dynamic>;
    }
    List<Map<String, dynamic>> att = [];
    if (json['attachments'] is List) {
      for (final e in json['attachments'] as List) {
        if (e is Map<String, dynamic>) att.add(e);
      }
    }
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num).toInt(),
      content: json['content'] as String? ?? '',
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      user: userMap != null ? ChatMessageUser.fromJson(userMap) : null,
      attachments: att,
      recipeSuggestions: directRecipeSuggestions.isNotEmpty
          ? directRecipeSuggestions
          : _recipeSuggestionsFromMetadata(metaMap),
    );
  }

  static Map<String, dynamic>? _normalizeMetadata(dynamic metadata) {
    if (metadata == null) return null;
    if (metadata is Map) {
      return Map<String, dynamic>.from(metadata);
    }
    if (metadata is String && metadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static List<ChatRecipeSuggestion> _recipeSuggestionsFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return const [];
    return _recipeSuggestionsFromRaw(metadata['recipe_suggestions']);
  }

  static List<ChatRecipeSuggestion> _recipeSuggestionsFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ChatRecipeSuggestion>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(ChatRecipeSuggestion.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }
}

class ChatMessageUser {
  final int id;
  final String name;
  final String? profilePhotoUrl;

  ChatMessageUser({required this.id, required this.name, this.profilePhotoUrl});

  factory ChatMessageUser.fromJson(Map<String, dynamic> json) {
    return ChatMessageUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }

  String? get displayProfilePhotoUrl => resolveStorageDisplayUrl(profilePhotoUrl);
}
