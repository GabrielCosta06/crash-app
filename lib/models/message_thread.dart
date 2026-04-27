class MessageThread {
  const MessageThread({
    required this.id,
    required this.crashpadId,
    required this.crashpadName,
    required this.guestId,
    required this.ownerId,
    this.messages = const [],
    required this.lastActivity,
  });

  final String id;
  final String crashpadId;
  final String crashpadName;
  final String guestId;
  final String ownerId;
  final List<ChatMessage> messages;
  final DateTime lastActivity;

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  bool includesUser(String userId) => guestId == userId || ownerId == userId;

  MessageThread copyWith({
    List<ChatMessage>? messages,
    DateTime? lastActivity,
  }) {
    return MessageThread(
      id: id,
      crashpadId: crashpadId,
      crashpadName: crashpadName,
      guestId: guestId,
      ownerId: ownerId,
      messages: messages ?? this.messages,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
}
