import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/**
 * Flutter Notification Service
 * Handles FCM background messages, foreground alerts, and local notification display.
 */
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Request Permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('User granted notification permission');
    }

    // 2. Setup Local Notifications for Foreground display
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initializationSettings);

    // 3. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('Foreground Message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 4. Handle Notification Taps (App opened from background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) print('Notification Tapped: ${message.data}');
      // Navigation logic would go here
    });
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  void _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = const AndroidNotificationDetails(
      'reliefnet_channel',
      'ReliefNet Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: android),
        payload: message.data.toString(),
      );
    }
  }
}

/**
 * GLOBAL BACKGROUND HANDLER
 * Must be a top-level function (not a class member)
 */
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, 
  // such as Firestore, make sure you call `Firebase.initializeApp()` first.
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print("Title: ${message.notification?.title}");
  }
  
  // Custom logic: update local database, trigger sync, etc.
}
