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

  static const AndroidNotificationChannel sosEmergencyChannel = AndroidNotificationChannel(
    'sos_emergency_channel',
    '🚨 แจ้งเตือนเหตุฉุกเฉิน SOS (Admin)',
    description: 'การแจ้งเตือนระดับวิกฤตเมื่อมีผู้ขอความช่วยเหลือ SOS ส่งตรงถึงมือถือเจ้าหน้าที่แม้ปิดแอพ',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const AndroidNotificationChannel generalAlertChannel = AndroidNotificationChannel(
    'general_water_alert_channel',
    '⚠️ เฝ้าระวัง & แจ้งเตือนทั่วไป (ไม่รบกวน)',
    description: 'การแจ้งเตือนระดับเฝ้าระวังและข้อมูลทั่วไป ไม่ส่งเสียงดังรบกวน',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: true,
  );

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
        requestCriticalPermission: true,
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
        await androidImplementation?.createNotificationChannel(sosEmergencyChannel);
        await androidImplementation?.createNotificationChannel(generalAlertChannel);
      }
    } catch (e) {
      debugPrint('[NotificationService] Local notification init error: $e');
    }
  }

  Future<void> showEmergencyNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    bool isCritical = false,
  }) async {
    if (kIsWeb) {
      showWebNotification(title, body, icon: 'icons/Icon-192.png');
      return;
    }

    try {
      final activeChannelId = channelId ??
          (isCritical ? sosEmergencyChannel.id : generalAlertChannel.id);

      final AndroidNotificationDetails androidPlatformChannelSpecifics;
      if (isCritical) {
        // ระดับวิกฤต: ดังไซเรน/เสียงเตือนฉุกเฉินเต็มพิกัด, สั่นเตือน และมี Full Screen Intent
        androidPlatformChannelSpecifics = AndroidNotificationDetails(
          activeChannelId,
          sosEmergencyChannel.name,
          channelDescription: sosEmergencyChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'sos_emergency',
          enableVibration: true,
          playSound: true,
          color: const Color(0xFFFF0000),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        );
      } else {
        // ระดับปกติ/เฝ้าระวัง: นุ่มนวล ไม่เด้งกินจอ ไม่เป็น Alarm ไม่ส่งเสียงดังรบกวนผู้ใช้
        androidPlatformChannelSpecifics = AndroidNotificationDetails(
          activeChannelId,
          generalAlertChannel.name,
          channelDescription: generalAlertChannel.description,
          importance: Importance.low,
          priority: Priority.low,
          ticker: 'water_general_alert',
          enableVibration: false,
          playSound: false,
          color: const Color(0xFFF59E0B),
          fullScreenIntent: false,
          category: AndroidNotificationCategory.status,
        );
      }
      
      final DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: isCritical,
        interruptionLevel: isCritical ? InterruptionLevel.critical : InterruptionLevel.passive,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
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

  /// Helper to trigger high-priority SOS emergency notification for admin
  Future<void> showSosNotification({
    required int id,
    required String victimName,
    required String situation,
    required String phone,
    String? note,
    String? coordinates,
  }) async {
    final title = '🚨 แจ้งเตือนฉุกเฉิน SOS: $victimName';
    final lines = <String>[
      'สถานการณ์: $situation',
      if (phone.isNotEmpty && phone != '-') 'เบอร์โทร: $phone',
      if (note != null && note.isNotEmpty) 'รายละเอียด: $note',
      if (coordinates != null && coordinates.isNotEmpty) 'พิกัด GPS: $coordinates',
    ];
    await showEmergencyNotification(
      id: id,
      title: title,
      body: lines.join('\n'),
      channelId: 'sos_emergency_channel',
    );
  }
}
