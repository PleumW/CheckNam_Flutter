import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'web_notification_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) {
      await initWebNotifications();
      return;
    }

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap here if needed
        }
      );

      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[NotificationService] Local notification init error: $e');
    }
  }

  Future<void> showEmergencyNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      showWebNotification(title, body, icon: 'icons/Icon-192.png');
      return;
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'emergency_alerts',
        'Emergency Alerts',
        channelDescription: 'แจ้งเตือนระดับอันตรายสูงสุด เช่น น้ำท่วม หรือไฟฟ้ารั่ว',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        enableVibration: true,
        playSound: true,
        color: Color(0xFFFF0000),
        fullScreenIntent: true,
      );
      
      const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosNotificationDetails,
      );
          
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing emergency notification: $e');
    }
  }
}
