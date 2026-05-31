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

  User applyPresence(UserPresence? presence) {
    if (presence == null) {
      return this;
    }

    return copyWith(
      isOnline: presence.isOnline,
      lastSeen: presence.lastSeen ?? lastSeen,
    );
  }
}

enum MessageType { text, image, voice, video, file, system }

class MessageReply {
  final String messageId;
  final String senderId;
  final String? senderName;
  final String? senderUsername;
  final String content;
  final MessageType type;
  final String? fileName;

  const MessageReply({
    required this.messageId,
    required this.senderId,
    this.senderName,
    this.senderUsername,
    required this.content,
    required this.type,
    this.fileName,
  });

  factory MessageReply.fromMessage(Message message) {
    return MessageReply(
      messageId: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      senderUsername: message.senderUsername,
      content: message.content,
      type: message.type,
      fileName: message.fileName,
    );
  }

  factory MessageReply.fromMap(dynamic value) {
    final map = Map<String, dynamic>.from(
      value as Map? ?? const <String, dynamic>{},
    );
    return MessageReply(
      messageId: map['messageId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String?,
      senderUsername: map['senderUsername'] as String?,
      content: map['content'] as String? ?? '',
      type: _messageTypeFromString(map['type'] as String?),
      fileName: map['fileName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'content': content,
      'type': type.name,
      'fileName': fileName,
    };
  }

  String get senderDisplayName {
    final name = senderName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username = senderUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return 'Message';
  }

  String get previewText {
    final trimmedContent = content.trim();
    if (trimmedContent.isNotEmpty) {
      return trimmedContent;
    }

    final trimmedFileName = fileName?.trim();
    if (trimmedFileName != null && trimmedFileName.isNotEmpty) {
      return trimmedFileName;
    }

    return switch (type) {
      MessageType.image => 'Photo',
      MessageType.video => 'Video',
      MessageType.voice => 'Voice message',
      MessageType.file => 'File',
      MessageType.system => 'System message',
      MessageType.text => 'Message',
    };
  }
}

class UserPresence {
  const UserPresence({required this.isOnline, this.lastSeen});

  final bool isOnline;
  final DateTime? lastSeen;

  factory UserPresence.fromMap(Map<Object?, Object?> map) {
    final state = (map['state'] as String?)?.toLowerCase();
    return UserPresence(
      isOnline: state == 'online',
      lastSeen: _asDateTime(map['last_changed']),
    );
  }
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderUsername;
  final String? senderAvatar;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? mediaUrl;
  final String? mediaStoragePath;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final MessageReply? replyTo;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderUsername,
    this.senderAvatar,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaStoragePath,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.replyTo,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    final replyMap = map['replyTo'];
    return Message(
      id: id,
      chatId: map['chatId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String?,
      senderUsername: map['senderUsername'] as String?,
      senderAvatar: map['senderAvatar'] as String?,
      content: map['content'] as String? ?? '',
      timestamp: _asDateTime(map['timestamp']) ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      type: _messageTypeFromString(map['type'] as String?),
      mediaUrl: map['mediaUrl'] as String?,
      mediaStoragePath: map['mediaStoragePath'] as String?,
      fileName: map['fileName'] as String?,
      mimeType: map['mimeType'] as String?,
      fileSize: (map['fileSize'] as num?)?.toInt(),
      replyTo: replyMap == null ? null : MessageReply.fromMap(replyMap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'senderAvatar': senderAvatar,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'mediaStoragePath': mediaStoragePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'replyTo': replyTo?.toMap(),
    };
  }

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderUsername,
    String? senderAvatar,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
    String? mediaUrl,
    String? mediaStoragePath,
    String? fileName,
    String? mimeType,
    int? fileSize,
    MessageReply? replyTo,
    bool clearReplyTo = false,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaStoragePath: mediaStoragePath ?? this.mediaStoragePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      replyTo: clearReplyTo ? null : replyTo ?? this.replyTo,
    );
  }
}

class Chat {
  final String id;
  final User otherUser;
  final bool isGroup;
  // for group chats
  final String? groupName;
  final String? groupAvatar;
  final String? groupCreatedBy;

  final Message? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> members;
  final String? lastMessageSenderName;
  final String? lastMessageSenderUsername;
  final String? lastMessageSenderAvatar;

  Chat({
    required this.id,
    required this.otherUser,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    this.groupCreatedBy,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    required this.createdAt,
    DateTime? updatedAt,
    this.members = const [],
    this.lastMessageSenderName,
    this.lastMessageSenderUsername,
    this.lastMessageSenderAvatar,
  }) : updatedAt = updatedAt ?? createdAt;

  String get displayName => isGroup
      ? (groupName?.trim().isNotEmpty == true ? groupName!.trim() : 'Group')
      : otherUser.name;

  String get displaySubtitle =>
      isGroup ? '${members.length} members' : otherUser.handle;

  String? get displayAvatar => isGroup ? groupAvatar : otherUser.avatar;

  factory Chat.fromMap({
    required String id,
    required Map<String, dynamic> map,
    required User otherUser,
    String? currentUserId,
  }) {
    final createdAt = _asDateTime(map['createdAt']) ?? DateTime.now();
    final updatedAt = _asDateTime(map['updatedAt']) ?? createdAt;
    final isGroup = (map['type'] as String?) == 'group';
    final lastMessageText = (map['lastMessageText'] as String?)?.trim();
    final unreadCounts = Map<String, dynamic>.from(
      map['unreadCounts'] as Map? ?? const <String, dynamic>{},
    );
    final unreadCount = currentUserId == null
        ? (map['unreadCount'] as int? ?? 0)
        : (unreadCounts[currentUserId] as int? ??
              map['unreadCount'] as int? ??
              0);

    Message? lastMessage;
    if (lastMessageText != null && lastMessageText.isNotEmpty) {
      lastMessage = Message(
        id: '${id}_last',
        chatId: id,
        senderId: map['lastMessageSenderId'] as String? ?? '',
        senderName: map['lastMessageSenderName'] as String?,
        senderUsername: map['lastMessageSenderUsername'] as String?,
        senderAvatar: map['lastMessageSenderAvatar'] as String?,
        content: lastMessageText,
        timestamp: _asDateTime(map['lastMessageAt']) ?? updatedAt,
        isRead: true,
        type: _messageTypeFromString(map['lastMessageType'] as String?),
      );
    }

    return Chat(
      id: id,
      otherUser: otherUser,
      isGroup: isGroup,
      groupName: map['groupName'] as String?,
      groupAvatar: map['groupAvatar'] as String?,
      groupCreatedBy: map['createdBy'] as String?,
      lastMessage: lastMessage,
      unreadCount: unreadCount,
      isPinned: map['isPinned'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      members: List<String>.from(map['members'] as List? ?? const <String>[]),
      lastMessageSenderName: map['lastMessageSenderName'] as String?,
      lastMessageSenderUsername: map['lastMessageSenderUsername'] as String?,
      lastMessageSenderAvatar: map['lastMessageSenderAvatar'] as String?,
    );
  }

  Chat copyWith({
    String? id,
    User? otherUser,
    bool? isGroup,
    String? groupName,
    String? groupAvatar,
    String? groupCreatedBy,
    Message? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? members,
    String? lastMessageSenderName,
    String? lastMessageSenderUsername,
    String? lastMessageSenderAvatar,
  }) {
    return Chat(
      id: id ?? this.id,
      otherUser: otherUser ?? this.otherUser,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      groupCreatedBy: groupCreatedBy ?? this.groupCreatedBy,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      lastMessageSenderName:
          lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageSenderUsername:
          lastMessageSenderUsername ?? this.lastMessageSenderUsername,
      lastMessageSenderAvatar:
          lastMessageSenderAvatar ?? this.lastMessageSenderAvatar,
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
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

MessageType _messageTypeFromString(String? value) {
  return MessageType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => MessageType.text,
  );
}

class ChatGroup {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<User> members;

  ChatGroup({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.members = const [],
  });
}
