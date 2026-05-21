import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_helper.dart';

class MobileNotificationHelper implements NotificationHelper {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    // 1. Request notifications permission for Android 13+ and iOS
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Initialize Flutter Local Notifications for local display (especially foreground)
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Optional payload click handler
      },
    );

    // Create custom high-priority notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'table_chat_channel',
      'Table Chat Notifications',
      description: 'Notifications for new table chat messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Listen to foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
          payload: message.data['tableNumber'],
        );
      }
    });
  }

  @override
  Future<void> showNotification({required String title, required String body, String? payload}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'table_chat_channel',
      'Table Chat Notifications',
      channelDescription: 'Notifications for new table chat messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  @override
  Future<String?> getDeviceToken() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await _fcm.getToken();
      }
    } catch (e) {
      // ignore token retrieval errors (e.g. no play services)
    }
    return null;
  }
}

NotificationHelper getNotificationHelper() => MobileNotificationHelper();
