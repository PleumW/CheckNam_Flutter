import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'providers/sensor_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/system_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/alert_screen.dart';
import 'screens/device_management_screen.dart';
import 'screens/safety_guide_screen.dart';
import 'screens/simulator_screen.dart';
import 'screens/login_screen.dart';
import 'screens/community_screen.dart';
import 'screens/admin_management_screen.dart';
import 'screens/proximity_alert_screen.dart';
import 'widgets/alert_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  debugPrint("Handling a background message: ${message.messageId}");

  try {
    if (message.notification == null && message.data.isNotEmpty) {
      await NotificationService().init();
      final title = message.data['title'] ?? '🚨 แจ้งเตือนฉุกเฉิน SOS!';
      final body = message.data['body'] ?? message.data['message'] ?? 'มีผู้ร้องขอความช่วยเหลือใหม่ในระบบ';
      final bool isCritical = title.contains('วิกฤต') ||
          title.contains('SOS') ||
          title.contains('ฉุกเฉิน') ||
          title.contains('อันตราย');
      await NotificationService().showEmergencyNotification(
        id: message.hashCode,
        title: title,
        body: body,
        isCritical: isCritical,
      );
    }
  } catch (e) {
    debugPrint("Background notification error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local / Web Notifications reliably
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("[NotificationService] Init error: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Setup Firebase Messaging
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // For flood and SOS alerts
      provisional: false,
      sound: true,
    );
    
    // Subscribe to general flood alerts topic (Only on native platforms)
    if (!kIsWeb) {
      try {
        await messaging.subscribeToTopic('alerts');
      } catch (e) {
        debugPrint("Subscribe to topic error: $e");
      }
    }
    
    try {
      String? token = await messaging.getToken();
      debugPrint("FCM Token: $token");
    } catch (_) {}

    // Handle foreground messages (including SOS alerts)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? '🚨 แจ้งเตือนฉุกเฉิน SOS';
      final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';
      final bool isCritical = title.contains('วิกฤต') ||
          title.contains('SOS') ||
          title.contains('ฉุกเฉิน') ||
          title.contains('อันตราย');
      if (title.isNotEmpty || body.isNotEmpty) {
        NotificationService().showEmergencyNotification(
          id: message.hashCode,
          title: title,
          body: body,
          isCritical: isCritical,
        );
      }
    });
  } catch (e) {
    debugPrint('Firebase initialization failed (not configured yet): $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SensorProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, LocationProvider>(
          create: (context) => context.read<LocationProvider>(),
          update: (context, auth, location) {
            location?.updateUserId(auth.user?.uid);
            return location!;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CheckNam',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return AlertManager(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/dashboard': (context) => const DashboardScreen(),
        '/map': (context) => const MapScreen(),
        '/community': (context) => const CommunityScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/system': (context) => const SystemScreen(),
        '/statistics': (context) => const StatisticsScreen(),
        '/alert_leakage': (context) => AlertScreen(
              title: 'สถานะ : ระวังกระแสไฟฟ้ารั่ว',
              waterLevel: context.read<SensorProvider>().waterLevel.toInt().toString(),
              type: 'leakage',
            ),
        '/admin': (context) => const AdminManagementScreen(),
        '/alert_flood': (context) {
          final sensor = context.read<SensorProvider>();
          final triggerDev = sensor.currentDevice ??
              sensor.devices.values.firstWhere(
                (d) => d.isFloodDanger,
                orElse: () => sensor.devices.values.first,
              );
          final bool isEmerg = triggerDev.isFloodEmergency || triggerDev.waterLevel >= 50.0;
          return AlertScreen(
            title: isEmerg ? 'สถานะ : วิกฤตสูงสุด' : 'สถานะ : วิกฤต',
            waterLevel: triggerDev.waterLevel.toInt().toString(),
            type: 'flood',
          );
        },
        '/alert_warning': (context) {
          final sensor = context.read<SensorProvider>();
          final triggerDev = sensor.currentDevice ??
              sensor.devices.values.firstWhere(
                (d) => d.isFloodWarning,
                orElse: () => sensor.devices.values.first,
              );
          return AlertScreen(
            title: 'สถานะ : เฝ้าระวัง',
            waterLevel: triggerDev.waterLevel.toInt().toString(),
            type: 'warning',
          );
        },
        '/guide_leakage': (context) => const SafetyGuideScreen(type: 'flood'),
        '/guide_flood': (context) => const SafetyGuideScreen(type: 'flood'),
        '/simulator': (context) => const SimulatorScreen(),
        '/device_management': (context) => const DeviceManagementScreen(),
        '/proximity_alert': (context) => const ProximityAlertScreen(),
        '/alert_early_warning': (context) {
          final sensor = context.read<SensorProvider>();
          final triggerDev = sensor.currentDevice ??
              sensor.devices.values.firstWhere(
                (d) => d.isEarlyWarning,
                orElse: () => sensor.devices.values.first,
              );
          return ProximityAlertScreen(device: triggerDev);
        },
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1E1E),
            body: Center(child: CircularProgressIndicator(color: Colors.blue)),
          );
        }
        
        if (auth.isAuthenticated) {
          return const MapScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
