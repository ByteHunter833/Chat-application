import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String username;
  final String? email;
  final String? avatar;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.avatar,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  String get handle => '@$username';

  factory User.fromMap(Map<String, dynamic> map, String id) {
    return User(
      id: id,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Unknown user',
      username: (map['username'] as String?)?.trim().toLowerCase() ?? '',
      email: map['email'] as String?,
      avatar: map['avatar'] as String? ?? map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: _asDateTime(map['lastSeen']),
      createdAt: _asDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'email': email,
      'avatar': avatar,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen == null ? null : Timestamp.fromDate(lastSeen!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? avatar,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum MessageType { text, image, voice, video }

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

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      chatId: map['chatId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      timestamp: _asDateTime(map['timestamp']) ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      type: _messageTypeFromString(map['type'] as String?),
      mediaUrl: map['mediaUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type.name,
      'mediaUrl': mediaUrl,
    };
  }

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
    String? mediaUrl,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}

class Chat {
  final String id;
  final User otherUser;
  final Message? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> members;

  Chat({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    required this.createdAt,
    DateTime? updatedAt,
    this.members = const [],
  }) : updatedAt = updatedAt ?? createdAt;

  factory Chat.fromMap({
    required String id,
    required Map<String, dynamic> map,
    required User otherUser,
  }) {
    final createdAt = _asDateTime(map['createdAt']) ?? DateTime.now();
    final updatedAt = _asDateTime(map['updatedAt']) ?? createdAt;
    final lastMessageText = (map['lastMessageText'] as String?)?.trim();

    Message? lastMessage;
    if (lastMessageText != null && lastMessageText.isNotEmpty) {
      lastMessage = Message(
        id: '${id}_last',
        chatId: id,
        senderId: map['lastMessageSenderId'] as String? ?? '',
        content: lastMessageText,
        timestamp: _asDateTime(map['lastMessageAt']) ?? updatedAt,
        isRead: true,
        type: _messageTypeFromString(map['lastMessageType'] as String?),
      );
    }

    return Chat(
      id: id,
      otherUser: otherUser,
      lastMessage: lastMessage,
      unreadCount: map['unreadCount'] as int? ?? 0,
      isPinned: map['isPinned'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      members: List<String>.from(map['members'] as List? ?? const <String>[]),
    );
  }

  Chat copyWith({
    String? id,
    User? otherUser,
    Message? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? members,
  }) {
    return Chat(
      id: id ?? this.id,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
    );
  }
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

DateTime? _asDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

MessageType _messageTypeFromString(String? value) {
  return MessageType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => MessageType.text,
  );
}
