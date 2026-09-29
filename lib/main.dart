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
import 'widgets/alert_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Local / Web Notifications
    await NotificationService().init();
    
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
      criticalAlert: true, // For flood alerts
      provisional: false,
      sound: true,
    );
    
    // Subscribe to topics (Only on native platforms)
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

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        NotificationService().showEmergencyNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'แจ้งเตือนจากส่วนกลาง',
          body: message.notification!.body ?? '',
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
              title: 'อันตราย! ตรวจพบกระแสไฟฟ้ารั่วไหลในน้ำ',
              waterLevel: context.read<SensorProvider>().waterLevel.toInt().toString(),
              type: 'leakage',
            ),
        '/admin': (context) => const AdminManagementScreen(),
        '/alert_flood': (context) => AlertScreen(
              title: 'อันตราย! ระดับน้ำสูงเกินกำหนด',
              waterLevel: context.read<SensorProvider>().waterLevel.toInt().toString(),
              type: 'flood',
            ),
        '/guide_leakage': (context) => const SafetyGuideScreen(type: 'leakage'),
        '/guide_flood': (context) => const SafetyGuideScreen(type: 'flood'),
        '/simulator': (context) => const SimulatorScreen(),
        '/device_management': (context) => const DeviceManagementScreen(),
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
