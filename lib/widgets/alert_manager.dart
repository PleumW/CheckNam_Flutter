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
  bool _hasShownLeakageAlert = false;
  bool _hasShownFloodAlert = false;
  bool _isShowingProximityModal = false;
  final Map<String, DateTime> _snoozedProximityDevices = {};
  Timer? _periodicCheckTimer;
  DateTime? _temporaryNavigationGracePeriodUntil;

  static void grantGracePeriod(Duration duration) {
    _instance?._temporaryNavigationGracePeriodUntil = DateTime.now().add(duration);
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkAlerts();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().addListener(_checkAlerts);
      context.read<AuthProvider>().addListener(_checkAlerts);
      context.read<LocationProvider>().addListener(_checkAlerts);
      context.read<SettingsProvider>().addListener(_checkAlerts);
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
    
    // ตรวจสอบว่าอยู่ในช่วงเวลาผ่อนผันการนำทางฉุกเฉินหรือไม่ (เช่น ผู้ใช้กำลังเปิดแผนที่เพื่ออพยพ)
    final bool isInGracePeriod = _temporaryNavigationGracePeriodUntil != null &&
        DateTime.now().isBefore(_temporaryNavigationGracePeriodUntil!);

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

      // --- Proximity & Early Warning Alert Check (เด้งหน้าต่างเตือนภัยขนาดใหญ่เมื่อเข้าใกล้จุดอันตราย หรือตรวจพบการเตือนภัยล่วงหน้า) ---
      if (settings.proximityAlertEnabled && !_isShowingProximityModal && !isInGracePeriod) {
        DeviceData? nearestTriggerDevice;
        double minDistance = double.infinity;

        final double baseRadius = settings.proximityAlertRadiusMeters;

        for (final device in sensor.devices.values) {
          final bool isEarlyWarningCrit = device.earlyWarningSeverity == EarlyWarningSeverity.critical;
          final bool isEarlyWarningAlert = device.earlyWarningSeverity == EarlyWarningSeverity.alert;
          final bool isEarlyWarningAdv = device.earlyWarningSeverity == EarlyWarningSeverity.advisory;

          final bool isCriticalDevice = device.isElectricalLeakage ||
              device.waterLevel >= 60.0 ||
              device.isFloodDanger ||
              isEarlyWarningCrit;

          final bool isHazard = isCriticalDevice ||
              device.isFloodWarning ||
              device.waterLevel >= 20.0 ||
              isEarlyWarningAlert ||
              isEarlyWarningAdv;

          if (!isHazard) continue;

          final double distM = distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(device.lat, device.lng));

          // คำนวณรัศมีตามระดับความอันตรายของน้ำ หรือการเตือนภัยล่วงหน้า
          double effectiveRadius = baseRadius;
          if (isCriticalDevice) {
            effectiveRadius = baseRadius.clamp(300.0, 2000.0);
          } else if (device.waterLevel >= 40.0 || isEarlyWarningAlert) {
            effectiveRadius = (baseRadius * 0.9).clamp(300.0, 2000.0);
          } else {
            effectiveRadius = (baseRadius * 0.8).clamp(250.0, 2000.0);
          }

          // ปลด Snooze หากผู้ใช้ออกห่างเกิน 1.5 เท่าของรัศมีเตือน
          if (distM > effectiveRadius * 1.5) {
            _snoozedProximityDevices.remove(device.id);
          }

          // ตรวจสอบว่าผู้ใช้อยู่ในระยะเสี่ยงหรือไม่
          if (distM <= effectiveRadius) {
            // ตรวจสอบสถานะ Snooze:
            // หากระดับน้ำวิกฤต หรือเตือนภัยล่วงหน้าวิกฤต (isCriticalDevice): จะไม่ติด Snooze 5 นาที!
            // ให้เด้งหน้าต่างเตือนตลอดเวลา (หน่วง cooldown เพียง 3 วินาที เพื่อให้แอนิเมชันและการสลับหน้าจอราบรื่น)
            if (_snoozedProximityDevices.containsKey(device.id)) {
              final lastTime = _snoozedProximityDevices[device.id]!;
              if (isCriticalDevice) {
                if (DateTime.now().difference(lastTime) < const Duration(seconds: 3)) {
                  continue;
                }
              } else {
                if (DateTime.now().difference(lastTime) < const Duration(minutes: 5)) {
                  continue;
                }
              }
            }

            if (distM < minDistance) {
              minDistance = distM;
              nearestTriggerDevice = device;
            }
          }
        }

        if (nearestTriggerDevice != null) {
          _isShowingProximityModal = true;
          _snoozedProximityDevices[nearestTriggerDevice.id] = DateTime.now();
          sensor.selectDevice(nearestTriggerDevice.id);

          // ส่งสัญญาณเสียงไซเรนทันทีเมื่อระดับวิกฤต (รวมวิกฤตเตือนภัยล่วงหน้า)
          if (nearestTriggerDevice.isElectricalLeakage ||
              nearestTriggerDevice.waterLevel >= 60.0 ||
              nearestTriggerDevice.isFloodDanger ||
              nearestTriggerDevice.earlyWarningSeverity == EarlyWarningSeverity.critical) {
            AudioAlarmService().startSiren();
          }

          widget.navigatorKey.currentState
              ?.pushNamed('/proximity_alert', arguments: nearestTriggerDevice)
              .then((_) {
            _isShowingProximityModal = false;
          });
        }
      }
    } else {
      anyLeakage = sensor.devices.values.any((d) => d.isElectricalLeakage);
      isNearLeakage = anyLeakage;
      anyFlood = sensor.devices.values.any((d) => d.isFloodDanger);

      // กรณีที่ผู้ใช้ไม่ได้เปิด GPS หรือยังไม่ทราบตำแหน่ง:
      // หากมีอุปกรณ์ใดระดับน้ำวิกฤต หรือตรวจพบการเตือนภัยล่วงหน้า ให้เด้งหน้าต่างแจ้งเตือนใหญ่
      if (settings.proximityAlertEnabled && !_isShowingProximityModal && !isInGracePeriod) {
        DeviceData? triggerDevice;
        for (final device in sensor.devices.values) {
          final bool isCrit = device.isElectricalLeakage ||
              device.waterLevel >= 60.0 ||
              device.isFloodDanger ||
              device.earlyWarningSeverity == EarlyWarningSeverity.critical;
          if (isCrit) {
            if (_snoozedProximityDevices.containsKey(device.id)) {
              final lastTime = _snoozedProximityDevices[device.id]!;
              if (DateTime.now().difference(lastTime) < const Duration(seconds: 3)) {
                continue;
              }
            }
            triggerDevice = device;
            break;
          }
        }

        // หากไม่มีวิกฤต ให้ตรวจหาอุปกรณ์ที่มีการเตือนภัยล่วงหน้า (Early Warning Alert)
        if (triggerDevice == null) {
          for (final device in sensor.devices.values) {
            final bool isEWAlert = device.earlyWarningSeverity == EarlyWarningSeverity.alert;
            if (isEWAlert) {
              if (_snoozedProximityDevices.containsKey(device.id)) {
                final lastTime = _snoozedProximityDevices[device.id]!;
                if (DateTime.now().difference(lastTime) < const Duration(minutes: 5)) {
                  continue;
                }
              }
              triggerDevice = device;
              break;
            }
          }
        }

        if (triggerDevice != null) {
          _isShowingProximityModal = true;
          _snoozedProximityDevices[triggerDevice.id] = DateTime.now();
          sensor.selectDevice(triggerDevice.id);

          final bool isCrit = triggerDevice.isElectricalLeakage ||
              triggerDevice.waterLevel >= 60.0 ||
              triggerDevice.isFloodDanger ||
              triggerDevice.earlyWarningSeverity == EarlyWarningSeverity.critical;

          if (isCrit) {
            AudioAlarmService().startSiren();
          }

          widget.navigatorKey.currentState
              ?.pushNamed('/proximity_alert', arguments: triggerDevice)
              .then((_) {
            _isShowingProximityModal = false;
          });
        }
      }
    }

    // จัดการเสียงไซเรนเตือนภัย: ทำงานเฉพาะเมื่อมีไฟฟ้ารั่วหรือระดับน้ำวิกฤตเท่านั้น
    final bool anyCriticalActive = anyLeakage ||
        anyFlood ||
        sensor.devices.values.any((d) =>
            d.waterLevel >= 60.0 ||
            d.isFloodDanger ||
            d.earlyWarningSeverity == EarlyWarningSeverity.critical);

    if (isNearLeakage || anyCriticalActive) {
      AudioAlarmService().startSiren();
    } else {
      // เมื่อระดับน้ำอยู่ในเกณฑ์ปลอดภัย หรือเฝ้าระวัง ให้หยุดเสียงไซเรนทันที (ไม่ดัง)
      AudioAlarmService().stopSiren();
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
      } catch (e) {
        debugPrint('Device not found for leakage alert');
      }
    } else if (routeName == '/alert_flood') {
      try {
        final device = sensor.devices.values.firstWhere((d) => d.isFloodDanger);
        sensor.selectDevice(device.id);
      } catch (e) {
        debugPrint('Device not found for flood alert');
      }
    }

    widget.navigatorKey.currentState?.pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
