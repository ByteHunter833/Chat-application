import 'dart:async';

import 'package:chat_app/utils/local_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../models/models.dart';
import '../repositories/chat_repository.dart';
import '../screens/chat_detail_screen.dart';
import 'app_navigator.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _isInitialized = false;
  static String? _activeUserId;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await LocalNotificationService().initLocalNotifications(
      onNotificationTap: (payload) {
        unawaited(_handleLocalNotificationPayload(payload));
      },
    );
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(handleForegroundMessage(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_handleOpenedMessage(initialMessage));
    }

    _isInitialized = true;
  }

  static Future<void> syncUserSession(User user) async {
    await initialize();
    if (_activeUserId != null && _activeUserId != user.id) {
      await clearSession(userId: _activeUserId);
    }

    _activeUserId = user.id;
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(user.id, token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final userId = _activeUserId;
      if (userId == null) {
        return;
      }
      unawaited(_saveToken(userId, token));
    });
  }

  static Future<void> clearSession({String? userId}) async {
    final resolvedUserId = userId ?? _activeUserId;
    final token = await _messaging.getToken();
    if (resolvedUserId != null && token != null) {
      await _removeToken(resolvedUserId, token);
    }

    _activeUserId = null;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  static Future<void> _saveToken(String userId, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'notificationTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  static Future<void> _removeToken(String userId, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'notificationTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String?;
    if (type == null) {
      return;
    }

    switch (type) {
      case 'chat_message':
        final chatId = data['chatId'] as String?;
        if (chatId == null || chatId.isEmpty) {
          return;
        }
        await _openChat(chatId);
        break;
    }
  }

  static Future<void> _handleLocalNotificationPayload(String? payload) async {
    if (payload == null || payload.isEmpty) {
      return;
    }

    await _openChat(payload);
  }

  static Future<void> _openChat(String chatId) async {
    final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return;
    }

    final chat = await ChatRepository(
      firestore: FirebaseFirestore.instance,
      realtimeDatabase: FirebaseDatabase.instance,
    ).getChatById(chatId: chatId, currentUserId: currentUserId);

    if (chat == null) {
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
    );
  }

  static Future<void> handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;

    final chatId = data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) {
      return;
    }

    // Later: check if current opened chat == chatId
    // if yes, don't show notification
    final notification = message.notification;
    final title = (notification?.title ?? data['title'] as String?)?.trim();
    final body = (notification?.body ?? data['body'] as String?)?.trim();
    final channelId = data['chatType'] == 'group'
        ? LocalNotificationService.groupChannel.id
        : LocalNotificationService.directChannel.id;

    await LocalNotificationService().showNotification(
      channelId: channelId,
      title: title?.isNotEmpty == true ? title! : 'New message',
      body: body?.isNotEmpty == true ? body! : 'Open chat',
      payload: chatId,
    );
  }
}
