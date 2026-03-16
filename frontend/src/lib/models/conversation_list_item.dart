/// Summary of a conversation for the list (other user, last message, unread count).
class ConversationListItem {
  final int id;
  final ConversationOtherUser otherUser;
  final ConversationLastMessage? lastMessage;
  final int unreadCount;
  final String? lastMessageAt;

  ConversationListItem({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  factory ConversationListItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? other = json['other_user'] is Map<String, dynamic>
        ? json['other_user'] as Map<String, dynamic>
        : null;
    Map<String, dynamic>? last = json['last_message'] is Map<String, dynamic>
        ? json['last_message'] as Map<String, dynamic>
        : null;
    return ConversationListItem(
      id: (json['id'] as num).toInt(),
      otherUser: other != null ? ConversationOtherUser.fromJson(other) : ConversationOtherUser(id: 0, name: ''),
      lastMessage: last != null ? ConversationLastMessage.fromJson(last) : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageAt: json['last_message_at'] as String?,
    );
  }
}

class ConversationOtherUser {
  final int id;
  final String name;

  ConversationOtherUser({required this.id, required this.name});

  factory ConversationOtherUser.fromJson(Map<String, dynamic> json) {
    return ConversationOtherUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

class ConversationLastMessage {
  final String content;
  final String createdAt;
  final bool isFromMe;

  ConversationLastMessage({
    required this.content,
    required this.createdAt,
    required this.isFromMe,
  });

  factory ConversationLastMessage.fromJson(Map<String, dynamic> json) {
    return ConversationLastMessage(
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      isFromMe: json['is_from_me'] as bool? ?? false,
    );
  }
}
