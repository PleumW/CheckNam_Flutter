import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';
import '../services/audio_alarm_service.dart';

class AlertManager extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  
  const AlertManager({super.key, required this.child, required this.navigatorKey});

  /// ให้ช่วงเวลาผ่อนผันการเด้งเตือนชั่วคราว (เช่น เมื่อผู้ใช้กดดูแผนที่เพื่ออพยพ หรือโทร SOS)
  static void grantEvacuationGracePeriod([Duration duration = const Duration(seconds: 25)]) {
    _AlertManagerState.grantGracePeriod(duration);
  }

  @override
  State<AlertManager> createState() => _AlertManagerState();
}

class _AlertManagerState extends State<AlertManager> {
  static _AlertManagerState? _instance;
  bool _hasShownFloodAlert = false;
  bool _hasShownWarningAlert = false;
  bool _isShowingProximityModal = false;
  final Map<String, DateTime> _snoozedProximityDevices = {};
  final Map<String, double> _lastTriggeredWaterLevel = {};
  final Map<String, FloodWarningLevel> _lastTriggeredWarningLevel = {};
  Timer? _periodicCheckTimer;
  DateTime? _temporaryNavigationGracePeriodUntil;

  static void grantGracePeriod(Duration duration) {
    _instance?._temporaryNavigationGracePeriodUntil = DateTime.now().add(duration);
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    // ตรวจสอบอย่างต่อเนื่องทุก 1 วินาที เพื่อให้ Takeover Screen ตอบสนองทันที
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAlerts();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().addListener(_checkAlerts);
      context.read<AuthProvider>().addListener(_checkAlerts);
      context.read<LocationProvider>().addListener(_checkAlerts);
      context.read<SettingsProvider>().addListener(_checkAlerts);
      _checkAlerts();
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    if (_instance == this) _instance = null;
    try {
      context.read<SensorProvider>().removeListener(_checkAlerts);
      context.read<AuthProvider>().removeListener(_checkAlerts);
      context.read<LocationProvider>().removeListener(_checkAlerts);
      context.read<SettingsProvider>().removeListener(_checkAlerts);
    } catch (_) {}
    super.dispose();
  }

  void _checkAlerts() {
    if (!mounted) return;

    final sensor = context.read<SensorProvider>();
    final location = context.read<LocationProvider>();
    final settings = context.read<SettingsProvider>();
    final userPos = location.currentPosition;
    
    // ตรวจสอบว่าอยู่ในช่วงเวลาผ่อนผันการนำทางฉุกเฉินหรือไม่ (เช่น เมื่อผู้ใช้เปิดแผนที่เพื่ออพยพ)
    final bool isInGracePeriod = _temporaryNavigationGracePeriodUntil != null &&
        DateTime.now().isBefore(_temporaryNavigationGracePeriodUntil!);

    // ใช้พิกัดจริง หรือใช้ Fallback (กรุงเทพฯ) เพื่อไม่ให้ระบบต้องรอค้นหาดาวเทียม GPS จนช้าเกินไป
    const Distance distanceCalc = Distance();
    final LatLng userLatLng = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : const LatLng(13.7563, 100.5018);
    const double maxAlertRadiusMeters = 100000.0; // รัศมี 100 กม.

    final bool anyFlood = sensor.devices.values.any((d) => 
        (d.isFloodDanger || d.waterLevel >= 30.0 || d.earlyWarningSeverity == EarlyWarningSeverity.critical) &&
        distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(d.lat, d.lng)) <= maxAlertRadiusMeters);
    final bool anyWarning = !anyFlood && sensor.devices.values.any((d) => 
        (d.isFloodWarning || d.waterLevel >= 10.0 || d.earlyWarningSeverity == EarlyWarningSeverity.alert) &&
        distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(d.lat, d.lng)) <= maxAlertRadiusMeters);

    // --- Proximity & Early Warning Takeover Alert Check ---
    if (settings.proximityAlertEnabled && !_isShowingProximityModal && !isInGracePeriod) {
      DeviceData? nearestTriggerDevice;
      double minDistance = double.infinity;

      for (final device in sensor.devices.values) {
        final bool isEarlyWarningCrit = device.earlyWarningSeverity == EarlyWarningSeverity.critical;
        final bool isEarlyWarningAlert = device.earlyWarningSeverity == EarlyWarningSeverity.alert;
        final bool isEarlyWarningAdv = device.earlyWarningSeverity == EarlyWarningSeverity.advisory;

        final bool isCriticalDevice = device.waterLevel >= 30.0 ||
            device.isFloodDanger ||
            isEarlyWarningCrit;

        final bool isHazard = isCriticalDevice ||
            device.isFloodWarning ||
            device.waterLevel >= 10.0 ||
            isEarlyWarningAlert ||
            isEarlyWarningAdv;

        if (!isHazard) continue;

        final double distM = distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(device.lat, device.lng));

        // ตรวจสอบเงื่อนไข: แสดงเฉพาะผู้ใช้อยู่ในรัศมีตรวจวัด (100 กม.)
        if (distM > maxAlertRadiusMeters) {
          continue;
        }

        // ตรวจสอบสถานะ Snooze / คูลดาวน์การแสดงผล:
        if (_snoozedProximityDevices.containsKey(device.id)) {
          final lastTime = _snoozedProximityDevices[device.id]!;
          final lastLevel = _lastTriggeredWaterLevel[device.id] ?? device.waterLevel;
          final lastWarn = _lastTriggeredWarningLevel[device.id] ?? device.floodWarningLevel;

          // หากระดับน้ำเพิ่มขึ้น (>= 1.5 ซม.) หรือสภาวะเตือนภัยยกระดับรุนแรงขึ้น -> ข้ามคูลดาวน์ เด้งเตือนทันที!
          final bool hasEscalated = (device.waterLevel - lastLevel) >= 1.5 ||
              device.floodWarningLevel.index > lastWarn.index;

          if (!hasEscalated) {
            final Duration elapsed = DateTime.now().difference(lastTime);
            if (isCriticalDevice) {
              // สภาวะวิกฤต: เด้งเตือนซ้ำถี่มาก (รอเพียง 6 วินาทีหลังจากปิดหน้าต่าง)
              if (elapsed < const Duration(seconds: 6)) {
                continue;
              }
            } else {
              // สภาวะเฝ้าระวัง/เสี่ยง: ปรับให้ถี่ขึ้นจากเดิม 5 นาที เหลือเพียง 15 วินาที!
              if (elapsed < const Duration(seconds: 15)) {
                continue;
              }
            }
          }
        }

        if (distM < minDistance) {
          minDistance = distM;
          nearestTriggerDevice = device;
        }
      }

      if (nearestTriggerDevice != null) {
        _isShowingProximityModal = true;
        sensor.selectDevice(nearestTriggerDevice.id);

        // ส่งสัญญาณเสียงไซเรนทันทีเมื่อระดับวิกฤตสูงสุด (แตะ 50 ซม. ขึ้นไป) หรือเสี่ยงวิกฤตล่วงหน้า
        if (nearestTriggerDevice.isFloodEmergency ||
            nearestTriggerDevice.waterLevel >= 50.0 ||
            nearestTriggerDevice.earlyWarningSeverity == EarlyWarningSeverity.critical) {
          AudioAlarmService().startSiren();
        }

        final targetDev = nearestTriggerDevice;
        widget.navigatorKey.currentState
            ?.pushNamed('/proximity_alert', arguments: targetDev)
            .then((_) {
          _isShowingProximityModal = false;
          // เริ่มนับเวลาคูลดาวน์หลังจากผู้ใช้กดปิด/ย่อหน้าต่างเตือนภัยลงแล้ว
          _snoozedProximityDevices[targetDev.id] = DateTime.now();
          _lastTriggeredWaterLevel[targetDev.id] = targetDev.waterLevel;
          _lastTriggeredWarningLevel[targetDev.id] = targetDev.floodWarningLevel;
        });
      }
    }

    // จัดการเสียงไซเรนเตือนภัย: ทำงานเฉพาะเมื่อมีระดับน้ำวิกฤตสูงสุด (Emergency >= 50 cm) ในรัศมี 100 กม. เท่านั้น
    final bool anyEmergencyActive = sensor.devices.values.any((d) =>
        (d.isFloodEmergency || d.waterLevel >= 50.0 || d.earlyWarningSeverity == EarlyWarningSeverity.critical) &&
        distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(d.lat, d.lng)) <= 100000.0);

    if (anyEmergencyActive) {
      AudioAlarmService().startSiren();
    } else if (!_isShowingProximityModal) {
      // เมื่อระดับน้ำยังไม่ถึงเกณฑ์วิกฤตสูงสุด (< 50 ซม.) และไม่มีหน้าต่างวิกฤตแสดงอยู่ ให้หยุดเสียงไซเรน
      AudioAlarmService().stopSiren();
    }

    // กรณีปิดระบบ Proximity Takeover ไว้ ให้ใช้หน้าต่างเตือนภัยแบบดั้งเดิมเป็น Fallback
    if (!settings.proximityAlertEnabled) {
      if (anyFlood && !_hasShownFloodAlert && !_isShowingProximityModal && !isInGracePeriod) {
        _hasShownFloodAlert = true;
        _hasShownWarningAlert = false;
        _showAlert('/alert_flood');
      } else if (!anyFlood) {
        _hasShownFloodAlert = false;
        if (anyWarning && !_hasShownWarningAlert && !_isShowingProximityModal && !isInGracePeriod) {
          _hasShownWarningAlert = true;
          _showAlert('/alert_warning');
        } else if (!anyWarning) {
          _hasShownWarningAlert = false;
        }
      }
    }
  }

  void _showAlert(String routeName) {
    final sensor = context.read<SensorProvider>();
    if (routeName == '/alert_flood') {
      try {
        final device = sensor.devices.values.firstWhere((d) => d.isFloodDanger);
        sensor.selectDevice(device.id);
      } catch (e) {
        debugPrint('Device not found for flood alert');
      }
    } else if (routeName == '/alert_warning') {
      try {
        final device = sensor.devices.values.firstWhere((d) => d.isFloodWarning);
        sensor.selectDevice(device.id);
      } catch (e) {
        debugPrint('Device not found for warning alert');
      }
    }

    widget.navigatorKey.currentState?.pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
