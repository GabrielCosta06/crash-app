class MessageThread {
  final String id;
  final String crashpadId;
  final String crashpadName;
  final String guestId;
  final String ownerId;
  final List<ChatMessage> messages;
  final DateTime lastActivity;

  MessageThread({
    required this.id,
    required this.crashpadId,
    required this.crashpadName,
    required this.guestId,
    required this.ownerId,
    this.messages = const [],
    required this.lastActivity,
  });

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });
}
