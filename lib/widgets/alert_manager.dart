import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../services/audio_alarm_service.dart';

class AlertManager extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  
  const AlertManager({super.key, required this.child, required this.navigatorKey});

  @override
  State<AlertManager> createState() => _AlertManagerState();
}

class _AlertManagerState extends State<AlertManager> {
  bool _hasShownLeakageAlert = false;
  bool _hasShownFloodAlert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().addListener(_checkAlerts);
      context.read<AuthProvider>().addListener(_checkAlerts);
    });
  }

  @override
  void dispose() {
    try {
      context.read<SensorProvider>().removeListener(_checkAlerts);
      context.read<AuthProvider>().removeListener(_checkAlerts);
    } catch (_) {}
    super.dispose();
  }

  void _checkAlerts() {
    if (!mounted) return;
    
    // Check if user is authenticated and not a guest
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.isGuest || auth.role == 'guest') {
      _hasShownLeakageAlert = false;
      _hasShownFloodAlert = false;
      return;
    }

    final sensor = context.read<SensorProvider>();
    final location = context.read<LocationProvider>();
    final userPos = location.currentPosition;
    
    bool anyLeakage = false;
    bool isNearLeakage = false;
    bool anyFlood = false;

    if (userPos != null) {
      const Distance distanceCalc = Distance();
      final userLatLng = LatLng(userPos.latitude, userPos.longitude);
      const double maxAlertRadiusMeters = 100000.0; // 100 กม.
      const double sirenDangerRadiusMeters = 500.0; // 500 เมตรสำหรับเสียงไซเรนกระแสไฟฟ้ารั่ว

      anyLeakage = sensor.devices.values.any((d) => 
          d.isElectricalLeakage && distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(d.lat, d.lng)) <= maxAlertRadiusMeters);
      isNearLeakage = sensor.devices.values.any((d) => 
          d.isElectricalLeakage && distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(d.lat, d.lng)) <= sirenDangerRadiusMeters);
      anyFlood = sensor.devices.values.any((d) => 
          d.isFloodDanger && distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(d.lat, d.lng)) <= maxAlertRadiusMeters);
    } else {
      anyLeakage = sensor.devices.values.any((d) => d.isElectricalLeakage);
      isNearLeakage = anyLeakage;
      anyFlood = sensor.devices.values.any((d) => d.isFloodDanger);
    }

    // Siren alarm management for electrical leakage
    if (isNearLeakage) {
      AudioAlarmService().startSiren();
    } else if (!anyLeakage) {
      AudioAlarmService().stopSiren();
      AudioAlarmService().resetMute();
    }

    if (anyLeakage && !_hasShownLeakageAlert) {
      _hasShownLeakageAlert = true;
      _showAlert('/alert_leakage');
    } else if (!anyLeakage) {
      _hasShownLeakageAlert = false;
    }

    if (anyFlood && !_hasShownFloodAlert) {
      _hasShownFloodAlert = true;
      _showAlert('/alert_flood');
    } else if (!anyFlood) {
      _hasShownFloodAlert = false;
    }
  }

  void _showAlert(String routeName) {
    // Select the device that caused the alert before navigating so the AlertScreen shows correct data
    final sensor = context.read<SensorProvider>();
    if (routeName == '/alert_leakage') {
      try {
        final device = sensor.devices.values.firstWhere((d) => d.isElectricalLeakage);
        sensor.selectDevice(device.id);
      } catch (e) {}
    } else if (routeName == '/alert_flood') {
      try {
        final device = sensor.devices.values.firstWhere((d) => d.isFloodDanger);
        sensor.selectDevice(device.id);
      } catch (e) {}
    }

    widget.navigatorKey.currentState?.pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
