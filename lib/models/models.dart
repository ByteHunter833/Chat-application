class User {
  final String id;
  final String name;
  final String? avatar;
  final bool isOnline;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.name,
    this.avatar,
    this.isOnline = false,
    this.lastSeen,
  });
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? mediaUrl;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.mediaUrl,
  });
}

enum MessageType { text, image, voice, video }

class Chat {
  final String id;
  final User otherUser;
  final Message? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    required this.createdAt,
  });
}

class ChatListState {
  final bool isLoading;
  final List<Chat> pinnedChats;
  final List<Chat> regularChats;
  final String? error;

  ChatListState({
    this.isLoading = false,
    this.pinnedChats = const [],
    this.regularChats = const [],
    this.error,
  });
}
