import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/models.dart';

class ChatRepository {
  ChatRepository({
    required FirebaseFirestore firestore,
    required FirebaseDatabase realtimeDatabase,
  }) : _firestore = firestore,
       _realtimeDatabase = realtimeDatabase;

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _realtimeDatabase;

  Stream<List<Chat>> watchChats(String currentUserId) async* {
    final snapshots = _firestore
        .collection('chats')
        .where('members', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots();

    await for (final snapshot in snapshots) {
      final chats = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();
          final members = List<String>.from(
            data['members'] as List? ?? const <String>[],
          );
          final otherUserId = members.firstWhere(
            (memberId) => memberId != currentUserId,
            orElse: () => '',
          );

          if (otherUserId.isEmpty) {
            return null;
          }

          final otherUser = await getUserById(otherUserId);
          if (otherUser == null) {
            return null;
          }

          return Chat.fromMap(
            id: doc.id,
            map: data,
            otherUser: otherUser,
            currentUserId: currentUserId,
          );
        }),
      );

      yield chats.whereType<Chat>().toList();
    }
  }

  Stream<List<Message>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<User>> searchUsersByUsername({
    required String query,
    String? excludeUserId,
  }) async {
    final normalizedQuery = query.trim().replaceFirst('@', '').toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <User>[];
    }

    final snapshot = await _firestore
        .collection('users')
        .orderBy('usernameLower')
        .startAt([normalizedQuery])
        .endAt(['$normalizedQuery\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => User.fromMap(doc.data(), doc.id))
        .where((user) => user.id != excludeUserId)
        .toList();
  }

  Future<User?> getUserById(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return User.fromMap(data, snapshot.id);
  }

  Future<Chat?> getChatById({
    required String chatId,
    required String currentUserId,
  }) async {
    final snapshot = await _firestore.collection('chats').doc(chatId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    final members = List<String>.from(data['members'] as List? ?? const []);
    final otherUserId = members.firstWhere(
      (memberId) => memberId != currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) {
      return null;
    }

    final otherUser = await getUserById(otherUserId);
    if (otherUser == null) {
      return null;
    }

    return Chat.fromMap(
      id: snapshot.id,
      map: data,
      otherUser: otherUser,
      currentUserId: currentUserId,
    );
  }

  Future<Chat> createOrGetDirectChat({
    required User currentUser,
    required User otherUser,
  }) async {
    final members = <String>[currentUser.id, otherUser.id]..sort();
    final chatId = members.join('_');
    final chatRef = _firestore.collection('chats').doc(chatId);
    final snapshot = await chatRef.get();

    if (!snapshot.exists) {
      await chatRef.set({
        'members': members,
        'memberUsernames': [currentUser.username, otherUser.username]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageAt': null,
        'lastMessageText': '',
        'lastMessageSenderId': '',
        'lastMessageType': MessageType.text.name,
        'unreadCounts': {currentUser.id: 0, otherUser.id: 0},
      }, SetOptions(merge: true));
    }

    final chatSnapshot = await chatRef.get();
    return Chat.fromMap(
      id: chatSnapshot.id,
      map: chatSnapshot.data() ?? const <String, dynamic>{},
      otherUser: otherUser,
      currentUserId: currentUser.id,
    );
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      text: text,
      type: MessageType.text,
    );
  }

  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String displayText,
    required MessageType type,
    required String mediaUrl,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      text: displayText,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
    );
  }

  Future<void> sendSystemMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? messageId,
  }) async {
    await _sendMessage(
      chatId: chatId,
      senderId: senderId,
      text: text,
      type: MessageType.system,
      messageId: messageId,
    );
  }

  Future<void> _sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required MessageType type,
    String? mediaUrl,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? messageId,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = messageId == null
        ? chatRef.collection('messages').doc()
        : chatRef.collection('messages').doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);
      final data = chatSnapshot.data() ?? const <String, dynamic>{};
      final members = List<String>.from(
        data['members'] as List? ?? const <String>[],
      );
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );

      for (final memberId in members) {
        if (memberId == senderId) {
          unreadCounts[memberId] = 0;
        } else {
          unreadCounts[memberId] = (unreadCounts[memberId] as int? ?? 0) + 1;
        }
      }

      transaction.set(messageRef, {
        'chatId': chatId,
        'senderId': senderId,
        'content': trimmedText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type.name,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
      });

      transaction.set(chatRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': trimmedText,
        'lastMessageSenderId': senderId,
        'lastMessageType': type.name,
        'unreadCounts': unreadCounts,
      }, SetOptions(merge: true));
    });
  }

  Future<void> markChatAsRead({
    required String chatId,
    required String currentUserId,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final unreadMessagesSnapshot = await chatRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (final doc in unreadMessagesSnapshot.docs) {
      final data = doc.data();
      if ((data['senderId'] as String?) == currentUserId) {
        continue;
      }

      batch.update(doc.reference, {'isRead': true});
    }

    batch.set(chatRef, {
      'unreadCounts': {currentUserId: 0},
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> setTypingState({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    final typingRef = _realtimeDatabase.ref('typing/$chatId/$userId');
    if (isTyping) {
      await typingRef.set(true);
      await typingRef.onDisconnect().remove();
      return;
    }

    await typingRef.remove();
    await typingRef.onDisconnect().cancel();
  }

  Stream<bool> watchTypingState({
    required String chatId,
    required String otherUserId,
  }) {
    return _realtimeDatabase
        .ref('typing/$chatId/$otherUserId')
        .onValue
        .map((event) => event.snapshot.value == true);
  }
}
