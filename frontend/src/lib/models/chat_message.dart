/// A single message in a conversation (from API or Reverb).
class ChatMessage {
  final int id;
  final int conversationId;
  final int userId;
  final String content;
  final String? readAt;
  final String? deletedAt;
  final String createdAt;
  final ChatMessageUser? user;
  final List<Map<String, dynamic>> attachments;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.content,
    this.readAt,
    this.deletedAt,
    required this.createdAt,
    this.user,
    List<Map<String, dynamic>>? attachments,
  }) : attachments = attachments ?? [];

  bool get isDeleted => deletedAt != null && deletedAt!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
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
      deletedAt: json['deleted_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      user: userMap != null ? ChatMessageUser.fromJson(userMap) : null,
      attachments: att,
    );
  }
}

class ChatMessageUser {
  final int id;
  final String name;

  ChatMessageUser({required this.id, required this.name});

  factory ChatMessageUser.fromJson(Map<String, dynamic> json) {
    return ChatMessageUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}
