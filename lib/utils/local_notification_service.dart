import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  factory LocalNotificationService() => instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const AndroidNotificationChannel directChannel =
      AndroidNotificationChannel(
        'direct_messages',
        'Direct Messages',
        importance: Importance.high,
        playSound: true,
      );

  static const AndroidNotificationChannel groupChannel =
      AndroidNotificationChannel(
        'group_messages',
        'Group Messages',
        importance: Importance.high,
      );

  Future<void> initLocalNotifications({
    void Function(String? payload)? onNotificationTap,
  }) async {
    if (_isInitialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();

    await flutterLocalNotificationsPlugin.initialize(
      settings: const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(directChannel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(groupChannel);
    _isInitialized = true;
  }

  Future<void> showNotification({
    required String channelId,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == directChannel.id ? directChannel.name : groupChannel.name,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iOSDetails = DarwinNotificationDetails();
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      ),
    );
  }
}
