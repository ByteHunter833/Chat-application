import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class ChatRepository {
  ChatRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

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

          return Chat.fromMap(id: doc.id, map: data, otherUser: otherUser);
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
      }, SetOptions(merge: true));
    }

    final chatSnapshot = await chatRef.get();
    return Chat.fromMap(
      id: chatSnapshot.id,
      map: chatSnapshot.data() ?? const <String, dynamic>{},
      otherUser: otherUser,
    );
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final batch = _firestore.batch();

    batch.set(messageRef, {
      'chatId': chatId,
      'senderId': senderId,
      'content': trimmedText,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': MessageType.text.name,
    });

    batch.set(chatRef, {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': trimmedText,
      'lastMessageSenderId': senderId,
      'lastMessageType': MessageType.text.name,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
