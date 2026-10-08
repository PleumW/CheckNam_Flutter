import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/email_otp_service.dart';
import 'weather_service.dart';

enum FloodWarningLevel { safe, warning, danger, emergency }

enum EarlyWarningSeverity { none, advisory, alert, critical }

class DeviceData {
  final String id;
  String name;
  double lat;
  double lng;
  double waterLevel;
  double waterFlow;
  double rainfall;
  String weatherStatus;
  double waterLevelThreshold;
  String stationType; // ชนิดสถานี เช่น 'station' หรือ 'network' (เครือข่ายสถานีตรวจวัด IoT ในรัศมี 20 กม.)
  
  // Early Warning Features (RoC and Virtual Sensor + Forecast Fusion)
  double risingSpeed; // cm per hour
  bool isRainingHeavy;
  int forecastRainProb30;
  int forecastRainProb60;
  int forecastRainProb90;

  // IoT Internet & Signal Telemetry
  int _signalPercent;
  int _signalRssi;
  String networkType;
  int pingMs;
  String? wifiSsid;
  String? ipAddress;
  bool hasWifiData;

  // Hardware Health & Energy Telemetry
  int batteryPercent;
  double batteryVoltage;
  double sensorHeight; // cm from sensor head to bed/ground

  // Sensor Online / Offline Telemetry
  bool isOnline;
  DateTime? lastSeen;
  DateTime? lastDataReceived;
  bool hasWaterLevelSensor;
  final bool isGpsLocked;

  // Station Category Helpers
  bool get isUpstream =>
      stationType == 'upstream' ||
      stationType == 'riverbank' ||
      id.contains('upstream') ||
      id.contains('riverbank') ||
      id.contains('khlong_1') ||
      id == 'device_1' ||
      id == 'device_test';

  bool get isDownstream =>
      stationType == 'downstream' ||
      stationType == 'urban' ||
      id.contains('downstream') ||
      id.contains('urban') ||
      id.contains('city') ||
      id.contains('khlong_2');

  // Backward compatibility aliases
  bool get isRiverbank => isUpstream;
  bool get isUrban => isDownstream;
  bool get isNetworkStation => stationType == 'network';

  String get stationTypeName {
    if (stationType == 'network') return 'สถานีเครือข่าย (รัศมี 20 กม.)';
    return 'สถานีตรวจวัด IoT';
  }

  IconData get stationTypeIcon => Icons.sensors_rounded;

  Color get stationTypeColor => const Color(0xFF0284C7);

  // Backward compatibility getters (ตัดไฟฟ้ารั่วออกแล้ว = คืนค่า false/0.0 เสมอ)
  bool get isElectricalLeakage => false;
  double get leakageProbability => 0.0;
  bool get hasCurrentSensor => false;

  // Hardware Model & Dynamic Diagnostics
  String? _boardModel;
  String get boardModel => _boardModel ?? 'ESP32-WROOM-32';
  set boardModel(String? val) => _boardModel = val;

  String? _firmware;
  String get firmware => _firmware ?? 'v2.0-auto';
  set firmware(String? val) => _firmware = val;

  Map<String, dynamic>? _modules;
  Map<String, dynamic> get modules => _modules ?? const {};
  set modules(Map<String, dynamic>? val) => _modules = val;

  DeviceData({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.waterLevel = 0.0,
    this.waterFlow = 5.0,
    this.rainfall = 5.0,
    this.weatherStatus = 'ปกติ',
    this.waterLevelThreshold = 50.0,
    this.stationType = 'upstream',
    this.risingSpeed = 0.0,
    this.isRainingHeavy = false,
    this.forecastRainProb30 = 20,
    this.forecastRainProb60 = 30,
    this.forecastRainProb90 = 15,
    int signalPercent = 80,
    int signalRssi = -60,
    this.networkType = 'Wi-Fi (2.4 GHz)',
    this.pingMs = 24,
    this.wifiSsid,
    this.ipAddress,
    this.hasWifiData = false,
    this.batteryPercent = 85,
    this.batteryVoltage = 3.9,
    this.sensorHeight = 200.0,
    this.isOnline = true,
    this.hasWaterLevelSensor = true,
    this.isGpsLocked = false,
    this.lastSeen,
    this.lastDataReceived,
    String? boardModel,
    String? firmware,
    Map<String, dynamic>? modules,
  // ignore: prefer_initializing_formals
  })  : _signalPercent = signalPercent,
        // ignore: prefer_initializing_formals
        _signalRssi = signalRssi,
        _boardModel = boardModel ?? 'ESP32-WROOM-32',
        _firmware = firmware ?? 'v2.0-auto',
        _modules = modules ?? const {};

  int get signalPercent => isDeviceOnline ? _signalPercent : 0;
  set signalPercent(int val) => _signalPercent = val;

  int get signalRssi => isDeviceOnline ? _signalRssi : -100;
  set signalRssi(int val) => _signalRssi = val;

  int get rawSignalPercent => _signalPercent;
  int get rawSignalRssi => _signalRssi;

  Map<String, dynamic> get dynamicModules {
    if (modules.isNotEmpty) return modules;
    final bool ultrasonicOk = isDeviceOnline && waterLevel >= 0 && waterLevel <= 300;
    return {
      'ultrasonic': {
        'name': 'เซนเซอร์วัดระดับน้ำ (Ultrasonic Sensor)',
        'model': 'รุ่น JSN-SR04T Waterproof Ultrasonic',
        'installed': hasWaterLevelSensor,
        'status': hasWaterLevelSensor ? (ultrasonicOk ? 'OK' : 'FAULT') : 'NOT_INSTALLED',
        'message': hasWaterLevelSensor
            ? (ultrasonicOk ? 'ปกติ • วัดได้ ${waterLevel.toStringAsFixed(1)} ซม.' : 'เซนเซอร์ชำรุด / อ่านค่าไม่ได้!')
            : 'ยังไม่ได้ติดตั้งเซนเซอร์วัดระดับน้ำ',
        'icon': 'water_drop',
      },
      'telemetry': {
        'name': 'โมดูลสื่อสาร IoT (ESP32 Gateway)',
        'model': 'ESP32-WROOM Wi-Fi / Telemetry',
        'installed': true,
        'status': isDeviceOnline ? 'OK' : 'OFFLINE',
        'message': isDeviceOnline ? 'เชื่อมต่อออนไลน์ปกติ ($networkType)' : 'ออฟไลน์ ขาดการเชื่อมต่อ',
        'icon': 'wifi',
      },
    };
  }

  static const int offlineTimeoutSeconds = 8; // ไวและแม่นยำสูง (ESP32 ส่งทุก 3 วิ หากขาดเกิน 8 วิ ถือว่าออฟไลน์ทันที)

  bool get isDeviceOnline {
    // 1. If hardware/software explicitly flagged offline
    if (!isOnline) return false;

    final now = DateTime.now();

    // 2. Check telemetry packet arrival on local clock (Zero clock-skew):
    if (lastDataReceived != null) {
      final int diffSec = now.difference(lastDataReceived!).inSeconds;
      return diffSec <= offlineTimeoutSeconds;
    }

    // 3. Sensor timestamp check (from ESP32 server timestamp if present):
    if (lastSeen != null) {
      final int diffSec = now.difference(lastSeen!).inSeconds;
      return diffSec <= offlineTimeoutSeconds;
    }

    // 4. Default: If no telemetry has arrived recently, device is offline!
    return false;
  }

  String get onlineStatusText => isDeviceOnline ? 'ออนไลน์' : 'ออฟไลน์ (ขาดการติดต่อ)';
  Color get onlineStatusColor => isDeviceOnline ? Colors.green : Colors.redAccent;
  IconData get onlineStatusIcon => isDeviceOnline ? Icons.sensors_rounded : Icons.sensors_off_rounded;

  int get signalBars {
    if (!isDeviceOnline) return 0;
    if (signalPercent >= 80) return 4;
    if (signalPercent >= 55) return 3;
    if (signalPercent >= 30) return 2;
    if (signalPercent > 0) return 1;
    return 0;
  }

  String get signalBarsText {
    if (!isDeviceOnline) return '0/4 ขีด (ออฟไลน์)';
    final b = signalBars;
    if (b == 4) return '4/4 ขีด (สัญญาณเต็ม)';
    if (b == 3) return '3/4 ขีด (ดีมาก)';
    if (b == 2) return '2/4 ขีด (ปานกลาง)';
    if (b == 1) return '1/4 ขีด (อ่อน)';
    return '0/4 ขีด (ไม่มีสัญญาณ)';
  }

  String get signalQualityText {
    if (!isDeviceOnline) return 'ไม่มีสัญญาณ (ออฟไลน์)';
    if (signalPercent >= 80) return 'ดีมาก (สัญญาณเสถียรสูง)';
    if (signalPercent >= 50) return 'ปานกลาง (ใช้งานได้ดี)';
    if (signalPercent >= 25) return 'สัญญาณอ่อน';
    if (signalPercent > 0) return 'สัญญาณอ่อนมาก (เสี่ยงหลุด)';
    return 'ไม่มีสัญญาณ';
  }

  Color get signalColor {
    if (!isDeviceOnline) return Colors.grey;
    if (signalPercent >= 80) return Colors.green;
    if (signalPercent >= 50) return Colors.blueAccent;
    if (signalPercent >= 25) return Colors.orange;
    return Colors.redAccent;
  }

  IconData get signalIcon {
    if (!isDeviceOnline) return Icons.wifi_off_rounded;
    if (signalPercent >= 80) return Icons.wifi_rounded;
    if (signalPercent >= 50) return Icons.wifi_2_bar_rounded;
    if (signalPercent >= 25) return Icons.wifi_1_bar_rounded;
    return Icons.signal_wifi_bad_rounded;
  }

  String get waterFlowStatus {
    if (waterFlow > 30) return 'ไหลเชี่ยว';
    if (waterFlow >= 10) return 'ปานกลาง';
    return 'นิ่ง';
  }

  // Multi-Sensor + Weather Forecast Fusion Engine
  double get compoundRisingSpeed {
    final double sensorRate = risingSpeed > 0 ? risingSpeed : 0.0;
    final double rainImpact = rainfall * 0.3;
    double forecastImpact = 0.0;
    if (forecastRainProb30 >= 70) {
      forecastImpact = 4.5 * (forecastRainProb30 / 100.0);
    } else if (forecastRainProb30 >= 50) {
      forecastImpact = 2.0;
    } else if (forecastRainProb30 >= 30) {
      forecastImpact = 0.8;
    }
    final double total = sensorRate + rainImpact + forecastImpact;
    return double.parse(total.toStringAsFixed(1));
  }

  EarlyWarningSeverity get earlyWarningSeverity {
    // 1. Critical Condition (Flash flood threat)
    if ((compoundRisingSpeed >= 12.0 && (forecastRainProb30 >= 70 || isRainingHeavy || rainfall >= 15.0)) ||
        (waterLevel >= 40.0 && compoundRisingSpeed >= 8.0 && forecastRainProb30 >= 60)) {
      return EarlyWarningSeverity.critical;
    }

    // 2. Alert Condition (Fast rising / High rain threat)
    if (risingSpeed >= 10.0 ||
        (compoundRisingSpeed >= 6.0 && forecastRainProb30 >= 60) ||
        (isRainingHeavy && waterLevel >= 15.0) ||
        (forecastRainProb30 >= 80 && waterLevel >= 20.0)) {
      return EarlyWarningSeverity.alert;
    }

    // 3. Advisory Condition (Noticeable rise or heavy rain risk)
    if (forecastRainProb30 >= 65 ||
        compoundRisingSpeed >= 4.0 ||
        rainfall >= 8.0 ||
        risingSpeed >= 3.0) {
      return EarlyWarningSeverity.advisory;
    }

    return EarlyWarningSeverity.none;
  }

  bool get isEarlyWarning =>
      earlyWarningSeverity == EarlyWarningSeverity.alert ||
      earlyWarningSeverity == EarlyWarningSeverity.critical;

  FloodWarningLevel get floodWarningLevel {
    if (waterLevel >= 50.0) return FloodWarningLevel.emergency;
    if (waterLevel >= 30.0) return FloodWarningLevel.danger;
    if (waterLevel >= 10.0) return FloodWarningLevel.warning;
    
    // Proactive Early Warning triggers escalation
    if (earlyWarningSeverity == EarlyWarningSeverity.critical) {
      return FloodWarningLevel.danger;
    }
    if (earlyWarningSeverity == EarlyWarningSeverity.alert) {
      return FloodWarningLevel.warning;
    }
    if (risingSpeed > 10.0 || isRainingHeavy || rainfall >= 30) {
      return FloodWarningLevel.warning;
    }
    
    return FloodWarningLevel.safe;
  }

  bool get isFloodEmergency => floodWarningLevel == FloodWarningLevel.emergency;
  bool get isFloodDanger => floodWarningLevel == FloodWarningLevel.danger || floodWarningLevel == FloodWarningLevel.emergency;
  bool get isFloodWarning => floodWarningLevel == FloodWarningLevel.warning;

  // ระยะทางที่เซ็นเซอร์ยิงวัดได้ (cm) = 100 cm - ระดับน้ำขังบนถนน (cm)
  double get sensorDistance => (100.0 - waterLevel).clamp(0.0, 100.0);

  // สภาวะอันตราย
  String get hazardStateText {
    if (waterLevel >= 50.0) return 'วิกฤตสูงสุด (Emergency)';
    if (waterLevel >= 30.0) return 'วิกฤต (Critical)';
    if (waterLevel >= 10.0) return 'เฝ้าระวัง (Warning)';
    return 'ปกติ (Normal)';
  }

  // การทำงานของฮาร์ดแวร์
  String get hardwareStatusText {
    if (waterLevel >= 50.0) return '🔴 ไฟแดงติด • 🔊 ไซเรนดังกระหึ่ม!';
    if (waterLevel >= 30.0) return '🔴 ไฟแดงติด • 🔇 Buzzer เงียบ';
    if (waterLevel >= 10.0) return '🟠 ไฟเหลืองติด • 🔇 Buzzer เงียบ';
    return '🟢 ไฟเขียวติด • 🔇 Buzzer เงียบ';
  }

  // เสียงไซเรนฮาร์ดแวร์ทำงาน (ดังเฉพาะน้ำแตะ 50 ซม. ขึ้นไป)
  bool get isHardwareBuzzerActive => waterLevel >= 50.0;

  // ผลกระทบและการสัญจรบนถนน
  String get trafficImpactText {
    if (waterLevel >= 50.0) {
      return 'รถเล็กและรถเก๋งเครื่องดับ 100% ห้ามสัญจรผ่านเด็ดขาด';
    }
    if (waterLevel >= 30.0) {
      return 'รถเก๋งเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด';
    }
    if (waterLevel >= 10.0) {
      return 'รถเก๋งสัญจรลำบาก มอเตอร์ไซค์เสี่ยงเครื่องดับ';
    }
    return 'ถนนแห้งหรือน้ำตื้น รถทุกชนิดสัญจรผ่านได้สะดวก';
  }

  String get systemStatus {
    if (!isDeviceOnline) return 'อุปกรณ์กำลัง Offline';
    if (isFloodEmergency) return 'วิกฤตสูงสุด! (ไซเรนดัง)';
    if (isFloodDanger) return 'วิกฤต! น้ำท่วมสูง';
    if (earlyWarningSeverity == EarlyWarningSeverity.critical) {
      return 'วิกฤตเตือนภัยล่วงหน้า (น้ำขึ้นเร็ว+ฝนตกหนัก)';
    }
    if (earlyWarningSeverity == EarlyWarningSeverity.alert) {
      return 'เตือนภัยล่วงหน้า! เสี่ยงน้ำท่วมฉับพลัน';
    }
    if (isFloodWarning) return 'เฝ้าระวังน้ำท่วม';
    if (earlyWarningSeverity == EarlyWarningSeverity.advisory) {
      return 'เฝ้าระวังฝนตกสะสม';
    }
    return 'ปกติ (Normal)';
  }

  Color get statusColor {
    if (!isDeviceOnline) return Colors.grey;
    if (isFloodEmergency) return const Color(0xFFDC2626);
    if (isFloodDanger) return const Color(0xFFEF4444);
    if (isFloodWarning || isEarlyWarning) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String get smartEarlyWarningTitle {
    switch (earlyWarningSeverity) {
      case EarlyWarningSeverity.critical:
        return '🚨 เตือนภัยล่วงหน้าขั้นวิกฤต (เซนเซอร์ + พยากรณ์ฝน)';
      case EarlyWarningSeverity.alert:
        return '⚠️ เตือนภัยล่วงหน้า (น้ำขึ้นเร็ว + เสี่ยงฝนตก)';
      case EarlyWarningSeverity.advisory:
        return 'ℹ️ เฝ้าระวังล่วงหน้า (สภาพอากาศมีผลต่อน้ำ)';
      case EarlyWarningSeverity.none:
        return 'สภาวะระดับน้ำปกติ';
    }
  }

  String get smartEarlyWarningBannerText {
    switch (earlyWarningSeverity) {
      case EarlyWarningSeverity.critical:
        return 'ความเร็วรวมคาดการณ์สูงถึง +${compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. '
            '(เซนเซอร์: ${risingSpeed.toStringAsFixed(1)} ซม./ชม., ฝน: $forecastRainProb30%) '
            '$compoundTimeToDangerText';
      case EarlyWarningSeverity.alert:
        return 'ตรวจพบแนวโน้มน้ำขึ้นเร็วรวมโอกาสฝนตก +${compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. '
            '$compoundTimeToDangerText';
      case EarlyWarningSeverity.advisory:
        return 'พยากรณ์โอกาสฝนตก $forecastRainProb30% อัตราการเพิ่มระดับน้ำคาดการณ์ +${compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม.';
      case EarlyWarningSeverity.none:
        return 'ระดับน้ำและสภาพอากาศอยู่ในเกณฑ์ปกติ';
    }
  }

  String get compoundTimeToDangerText {
    if (isFloodDanger || waterLevel >= waterLevelThreshold) {
      return 'อยู่ในระดับวิกฤตแล้ว (${waterLevel.toStringAsFixed(1)} / ${waterLevelThreshold.toStringAsFixed(1)} ซม.)';
    }
    final double speed = compoundRisingSpeed;
    if (speed > 0.5 && waterLevel < waterLevelThreshold) {
      final double diff = waterLevelThreshold - waterLevel;
      final double hours = diff / speed;
      final int minutes = (hours * 60).round();
      if (minutes <= 0) {
        return 'คาดว่าจะถึงระดับวิกฤตทันที';
      } else if (minutes < 60) {
        return 'คาดว่าจะถึงระดับวิกฤตในอีก ~$minutes นาที (รวมฝน)';
      } else {
        final int h = minutes ~/ 60;
        final int m = minutes % 60;
        return 'คาดว่าจะถึงระดับวิกฤตในอีก ~$h ชม. $m นาที (รวมฝน)';
      }
    }
    if (risingSpeed <= 0 && forecastRainProb30 < 30) {
      return 'สถานการณ์ทรงตัว / มีแนวโน้มลดลง';
    }
    return 'ระดับน้ำยังต่ำกว่าเกณฑ์วิกฤต';
  }

  Color get earlyWarningColor {
    switch (earlyWarningSeverity) {
      case EarlyWarningSeverity.critical:
        return const Color(0xFFEF4444);
      case EarlyWarningSeverity.alert:
        return const Color(0xFFF97316);
      case EarlyWarningSeverity.advisory:
        return const Color(0xFFEAB308);
      case EarlyWarningSeverity.none:
        return const Color(0xFF10B981);
    }
  }

  IconData get earlyWarningIcon {
    switch (earlyWarningSeverity) {
      case EarlyWarningSeverity.critical:
        return Icons.warning_rounded;
      case EarlyWarningSeverity.alert:
        return Icons.speed_rounded;
      case EarlyWarningSeverity.advisory:
        return Icons.cloudy_snowing;
      case EarlyWarningSeverity.none:
        return Icons.check_circle_outline_rounded;
    }
  }

  // Battery Telemetry Getters
  IconData get batteryIcon {
    if (batteryPercent >= 90) return Icons.battery_full_rounded;
    if (batteryPercent >= 60) return Icons.battery_5_bar_rounded;
    if (batteryPercent >= 35) return Icons.battery_3_bar_rounded;
    if (batteryPercent >= 15) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  Color get batteryColor {
    if (batteryPercent >= 50) return const Color(0xFF10B981);
    if (batteryPercent >= 20) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get batteryStatusText => '$batteryPercent% (${batteryVoltage.toStringAsFixed(1)}V)';

  // Smart Analytics & Prediction Getters
  String get trendStatusText {
    final double effectiveSpeed = compoundRisingSpeed > risingSpeed ? compoundRisingSpeed : risingSpeed;
    if (effectiveSpeed > 12.0) return 'ระดับน้ำกำลังเพิ่มขึ้นอย่างรวดเร็ว (เสี่ยงสูง)';
    if (effectiveSpeed > 3.0) return 'ระดับน้ำมีแนวโน้มเพิ่มขึ้น (รวมปัจจัยฝน)';
    if (risingSpeed < -3.0 && compoundRisingSpeed <= 1.0) return 'ระดับน้ำกำลังลดลง';
    return 'ระดับน้ำทรงตัว (ปลอดภัย)';
  }

  Color get trendColor {
    final double effectiveSpeed = compoundRisingSpeed > risingSpeed ? compoundRisingSpeed : risingSpeed;
    if (effectiveSpeed > 12.0) return const Color(0xFFEF4444);
    if (effectiveSpeed > 3.0) return const Color(0xFFF59E0B);
    if (risingSpeed < -3.0 && compoundRisingSpeed <= 1.0) return const Color(0xFF10B981);
    return const Color(0xFF3B82F6);
  }

  IconData get trendIcon {
    final double effectiveSpeed = compoundRisingSpeed > risingSpeed ? compoundRisingSpeed : risingSpeed;
    if (effectiveSpeed > 12.0) return Icons.trending_up_rounded;
    if (effectiveSpeed > 3.0) return Icons.arrow_upward_rounded;
    if (risingSpeed < -3.0 && compoundRisingSpeed <= 1.0) return Icons.trending_down_rounded;
    return Icons.trending_flat_rounded;
  }

  String get estimatedTimeToDangerText => compoundTimeToDangerText;

  // Proactive Water Level Forecast (Edge App AI & Weather Fusion)
  double get predictedWaterLevel30 {
    if (!isDeviceOnline) return 0.0;
    final double projected = waterLevel + (compoundRisingSpeed * 0.5);
    return max(0.0, double.parse(projected.toStringAsFixed(1)));
  }

  double get predictedWaterLevel60 {
    if (!isDeviceOnline) return 0.0;
    final double projected = waterLevel + (compoundRisingSpeed * 1.0);
    return max(0.0, double.parse(projected.toStringAsFixed(1)));
  }

  FloodWarningLevel get predictedWarningLevel30 {
    if (!isDeviceOnline) return FloodWarningLevel.safe;
    if (predictedWaterLevel30 >= 50.0) {
      return FloodWarningLevel.emergency;
    }
    if (predictedWaterLevel30 >= 30.0 || (waterLevelThreshold > 0 && predictedWaterLevel30 >= waterLevelThreshold)) {
      return FloodWarningLevel.danger;
    }
    if (predictedWaterLevel30 >= 10.0) {
      return FloodWarningLevel.warning;
    }
    return FloodWarningLevel.safe;
  }

  FloodWarningLevel get predictedWarningLevel60 {
    if (!isDeviceOnline) return FloodWarningLevel.safe;
    if (predictedWaterLevel60 >= 50.0) {
      return FloodWarningLevel.emergency;
    }
    if (predictedWaterLevel60 >= 30.0 || (waterLevelThreshold > 0 && predictedWaterLevel60 >= waterLevelThreshold)) {
      return FloodWarningLevel.danger;
    }
    if (predictedWaterLevel60 >= 10.0) {
      return FloodWarningLevel.warning;
    }
    return FloodWarningLevel.safe;
  }

  String get proactiveForecastSummary {
    if (!isDeviceOnline) {
      return 'อุปกรณ์ออฟไลน์ - ไม่สามารถพยากรณ์ล่วงหน้าได้';
    }
    final double p30 = predictedWaterLevel30;
    final double p60 = predictedWaterLevel60;
    final double diff30 = p30 - waterLevel;
    final String sign30 = diff30 >= 0 ? '+' : '';

    if (earlyWarningSeverity == EarlyWarningSeverity.critical || p30 >= 50.0) {
      return '🚨 วิกฤต! อีก 30 นาที คาดระดับน้ำแตะ $p30 ซม. ($sign30${diff30.toStringAsFixed(1)} ซม.) | 60 นาทีแตะ $p60 ซม. เสี่ยงน้ำท่วมฉับพลันสูง';
    } else if (earlyWarningSeverity == EarlyWarningSeverity.alert || p30 >= 30.0) {
      return '⚠️ เตือนภัย! อีก 30 นาที คาดระดับน้ำเพิ่มเป็น $p30 ซม. ($sign30${diff30.toStringAsFixed(1)} ซม.) ร่วมกับโอกาสฝน $forecastRainProb30%';
    } else if (earlyWarningSeverity == EarlyWarningSeverity.advisory || p30 >= 10.0) {
      return 'ℹ️ เฝ้าระวังฝน! คาดการณ์ 30 นาทีข้างหน้าระดับน้ำ $p30 ซม. | โอกาสฝน $forecastRainProb30%';
    } else {
      return '🟢 สภาวะปกติ: คาดการณ์ระดับน้ำ 30-60 นาทีข้างหน้าทรงตัวที่ $p30 - $p60 ซม.';
    }
  }

  // Flood Risk Probability (0 - 100%)
  int get floodRiskProbability30 {
    if (!isDeviceOnline) return 0;
    if (waterLevel >= 50.0) return 100;
    if (waterLevel >= 30.0) return 90;
    final double thresh = (waterLevelThreshold > 0 && waterLevelThreshold <= 50.0) ? waterLevelThreshold : 30.0;
    final double p30 = predictedWaterLevel30;
    if (p30 >= 50.0) return min(99, 90 + (forecastRainProb30 * 0.1).round());
    if (p30 >= thresh) {
      return min(95, 80 + (forecastRainProb30 * 0.14).round());
    }
    final double ratio = (p30 / thresh).clamp(0.0, 1.0);
    double prob = ratio * ratio * 75.0;
    if (compoundRisingSpeed > 5.0) {
      prob += (compoundRisingSpeed / 20.0).clamp(0.0, 1.0) * 15.0;
    }
    prob += (forecastRainProb30 / 100.0) * 15.0 * ratio;
    return prob.round().clamp(0, 95);
  }

  int get floodRiskProbability60 {
    if (!isDeviceOnline) return 0;
    if (waterLevel >= 50.0) return 100;
    if (waterLevel >= 30.0) return 90;
    final double thresh = (waterLevelThreshold > 0 && waterLevelThreshold <= 50.0) ? waterLevelThreshold : 30.0;
    final double p60 = predictedWaterLevel60;
    if (p60 >= 50.0) return min(99, 90 + (forecastRainProb60 * 0.1).round());
    if (p60 >= thresh) {
      return min(95, 80 + (forecastRainProb60 * 0.14).round());
    }
    final double ratio = (p60 / thresh).clamp(0.0, 1.0);
    double prob = ratio * ratio * 75.0;
    if (compoundRisingSpeed > 5.0) {
      prob += (compoundRisingSpeed / 20.0).clamp(0.0, 1.0) * 15.0;
    }
    prob += (forecastRainProb60 / 100.0) * 15.0 * ratio;
    return prob.round().clamp(0, 95);
  }
}

class SosRequest {
  final String id;
  final String userName;
  final String phoneNumber;
  final double lat;
  final double lng;
  final String situation;
  final String note;
  final String status; // 'pending', 'in_progress', 'resolved'
  final DateTime timestamp;
  final String nationalId;
  final String dob;
  final String nickname;
  final String englishName;

  SosRequest({
    required this.id,
    required this.userName,
    required this.phoneNumber,
    required this.lat,
    required this.lng,
    required this.situation,
    this.note = '',
    this.status = 'pending',
    required this.timestamp,
    this.nationalId = '',
    this.dob = '',
    this.nickname = '',
    this.englishName = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userName': userName,
        'phoneNumber': phoneNumber,
        'lat': lat,
        'lng': lng,
        'situation': situation,
        'note': note,
        'status': status,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'nationalId': nationalId,
        'dob': dob,
        'nickname': nickname,
        'englishName': englishName,
      };

  static DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final intVal = int.tryParse(raw);
      if (intVal != null) {
        return DateTime.fromMillisecondsSinceEpoch(intVal);
      }
      final dateVal = DateTime.tryParse(raw);
      if (dateVal != null) {
        return dateVal;
      }
    }
    return DateTime.now();
  }

  factory SosRequest.fromJson(String id, Map<dynamic, dynamic> json) {
    final rawUser = json['userName'] ?? json['name'] ?? json['user'] ?? json['reporterName'];
    final rawPhone = json['phoneNumber'] ?? json['phone'] ?? json['tel'] ?? json['reporterPhone'];
    final rawSituation = json['situation'] ?? json['title'] ?? json['type'];
    final rawNote = json['note'] ?? json['description'] ?? json['detail'];
    final rawStatus = json['status'];
    final rawTime = json['timestamp'] ?? json['createdAt'] ?? json['time'];
    final rawNationalId = json['nationalId'] ?? json['idCard'] ?? '';
    final rawDob = json['dob'] ?? json['birthDate'] ?? '';
    final rawNickname = json['nickname'] ?? '';
    final rawEnglishName = json['englishName'] ?? json['nameEn'] ?? '';

    return SosRequest(
      id: id,
      userName: (rawUser != null && rawUser.toString().trim().isNotEmpty) ? rawUser.toString().trim() : 'ผู้ประสบภัย',
      phoneNumber: (rawPhone != null && rawPhone.toString().trim().isNotEmpty) ? rawPhone.toString().trim() : '-',
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : (double.tryParse(json['lat']?.toString() ?? '') ?? 0.0),
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : (double.tryParse(json['lng']?.toString() ?? '') ?? 0.0),
      situation: (rawSituation != null && rawSituation.toString().trim().isNotEmpty) ? rawSituation.toString().trim() : 'ขอความช่วยเหลือด่วน',
      note: rawNote?.toString() ?? '',
      status: (rawStatus != null && rawStatus.toString().trim().isNotEmpty) ? rawStatus.toString().trim() : 'pending',
      timestamp: _parseTimestamp(rawTime),
      nationalId: rawNationalId.toString(),
      dob: rawDob.toString(),
      nickname: rawNickname.toString(),
      englishName: rawEnglishName.toString(),
    );
  }
}

class AlertHistoryItem {
  final DateTime time;
  final String title;
  final String subtitle;
  final String type; // 'leakage', 'danger', 'warning', 'safe'

  AlertHistoryItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'title': title,
        'subtitle': subtitle,
        'type': type,
      };

  factory AlertHistoryItem.fromJson(Map<String, dynamic> json) => AlertHistoryItem(
        time: DateTime.parse(json['time']),
        title: json['title'],
        subtitle: json['subtitle'],
        type: json['type'],
      );
}

class SensorProvider with ChangeNotifier {
  Map<String, DeviceData> _devices = {};
  String _selectedDeviceId = 'station_upstream';

  final Set<String> _deletedDeviceIds = {};
  Set<String> get deletedDeviceIds => Set.unmodifiable(_deletedDeviceIds);

  // Inter-device proximity flood alerts
  final Map<String, String> _deviceProximityFloodAlerts = {};
  Map<String, String> get deviceProximityFloodAlerts => _deviceProximityFloodAlerts;
  bool get hasProximityFloodAlert => _deviceProximityFloodAlerts.isNotEmpty;
  String? get proximityFloodAlertMessage {
    if (_deviceProximityFloodAlerts.isEmpty) return null;
    for (final msg in _deviceProximityFloodAlerts.values) {
      if (msg.contains('เตือนภัยมวลน้ำหลาก') || msg.contains('เตือนภัยน้ำหนุนย้อนกลับ')) {
        return msg;
      }
    }
    return _deviceProximityFloodAlerts.values.first;
  }

  bool hasProximityAlertFor(String deviceId) => _deviceProximityFloodAlerts.containsKey(deviceId);
  String? proximityAlertFor(String deviceId) => _deviceProximityFloodAlerts[deviceId];

  final Set<String> _notifiedProximityPairs = {};

  final DatabaseReference? _dbRef;
  bool _isFirebaseInitialized = false;

  final Map<String, List<double>> _deviceWaterLevelHistory = {};
  final Map<String, List<double>> _deviceRainfallHistory = {};
  final Map<String, List<double>> _deviceWaterFlowHistory = {};
  Timer? _historyTimer;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  final Map<String, List<Map<String, dynamic>>> _deviceHistory24h = {};
  final Map<String, List<Map<String, dynamic>>> _deviceHistory7d = {};
  final Set<String> _historyFetchedDeviceIds = {};
  
  List<Map<String, dynamic>> get history24h {
    if (!_deviceHistory24h.containsKey(_selectedDeviceId) || _deviceHistory24h[_selectedDeviceId]!.isEmpty) {
      _deviceHistory24h[_selectedDeviceId] = _generateFallbackHistory(_selectedDeviceId, hours: 24);
    }
    return _deviceHistory24h[_selectedDeviceId]!;
  }

  List<Map<String, dynamic>> get history7d {
    if (!_deviceHistory7d.containsKey(_selectedDeviceId) || _deviceHistory7d[_selectedDeviceId]!.isEmpty) {
      _deviceHistory7d[_selectedDeviceId] = _generateFallbackHistory(_selectedDeviceId, hours: 168);
    }
    return _deviceHistory7d[_selectedDeviceId]!;
  }

  List<Map<String, dynamic>> _generateFallbackHistory(String deviceId, {required int hours}) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> list = [];
    final device = _devices[deviceId];
    final double baseLevel = device?.waterLevel ?? 25.0;
    final int deviceHash = deviceId.hashCode.abs();
    final double amplitude = (deviceHash % 12) + 6.0;

    final int stepHours = hours > 24 ? 4 : 1;
    final int count = hours ~/ stepHours;

    for (int i = count; i >= 0; i--) {
      final time = now.subtract(Duration(hours: i * stepHours));
      final double wave = ((i % 6) - 3) * (amplitude / 3.0) + (i % 2 == 0 ? 1.5 : -1.5);
      final double wl = (baseLevel + wave).clamp(5.0, 190.0);
      final double rain = ((i + (deviceHash % 4)) % 6 == 0) ? (6.0 + (i % 3) * 6.0) : 0.0;
      final double flow = 4.0 + (i % 5) * 1.5;

      list.add({
        'timestamp': time.millisecondsSinceEpoch,
        'waterLevel': double.parse(wl.toStringAsFixed(1)),
        'rainfall': double.parse(rain.toStringAsFixed(1)),
        'waterFlow': double.parse(flow.toStringAsFixed(1)),
      });
    }
    return list;
  }

  Timer? _weatherSyncTimer;
  DateTime? _lastWeatherSyncTime;

  void updateRainfallFromWeatherApi({
    String? deviceId,
    required double precipitation,
    required String description,
    required int prob30,
    int? prob60,
    int? prob90,
  }) {
    bool updated = false;
    final targetDevices = (deviceId != null && _devices.containsKey(deviceId))
        ? [_devices[deviceId]!]
        : _devices.values;

    for (final device in targetDevices) {
      final double effectiveRainfall = WeatherService.isMockEnabled
          ? precipitation
          : (precipitation > 0 ? precipitation : (prob30 >= 75 ? 10.0 : 0.0));
      final int effectiveProb60 = prob60 ?? device.forecastRainProb60;
      final int effectiveProb90 = prob90 ?? device.forecastRainProb90;

      if (device.rainfall != effectiveRainfall ||
          device.weatherStatus != description ||
          device.forecastRainProb30 != prob30 ||
          device.forecastRainProb60 != effectiveProb60 ||
          device.forecastRainProb90 != effectiveProb90) {
        device.rainfall = effectiveRainfall;
        device.weatherStatus = description;
        device.forecastRainProb30 = prob30;
        device.forecastRainProb60 = effectiveProb60;
        device.forecastRainProb90 = effectiveProb90;
        device.isRainingHeavy = effectiveRainfall >= 20.0 || prob30 >= 75;
        updated = true;
      }
    }
    if (updated) {
      _checkAndTriggerNotifications();
      notifyListeners();
    }
  }

  void _startWeatherSyncTimer() {
    _weatherSyncTimer?.cancel();
    // Auto-sync weather forecast from Open-Meteo API every 10 minutes
    _weatherSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      syncWeatherForecast();
    });
    // Initial fetch on app start
    Future.microtask(() => syncWeatherForecast(force: true));
  }

  Future<void> syncWeatherForecast({String? deviceId, bool force = false}) async {
    final now = DateTime.now();
    if (!force && !WeatherService.isMockEnabled && _lastWeatherSyncTime != null && now.difference(_lastWeatherSyncTime!).inMinutes < 2) {
      return;
    }
    _lastWeatherSyncTime = now;

    try {
      final targetId = deviceId ?? _selectedDeviceId;
      final dev = _devices[targetId] ?? (_devices.isNotEmpty ? _devices.values.first : null);
      if (dev == null) return;

      final weather = await WeatherService.fetchWeather(dev.lat, dev.lng);
      if (weather.isNotEmpty) {
        final double precip = ((weather['precipitation'] ?? 0.0) as num).toDouble();
        final String desc = weather['description']?.toString() ?? 'ปกติ';
        final int p30 = (weather['prob30'] ?? 10) as int;
        final int p60 = (weather['prob60'] ?? 20) as int;
        final int p90 = (weather['prob90'] ?? 15) as int;

        updateRainfallFromWeatherApi(
          deviceId: WeatherService.isMockEnabled ? null : targetId,
          precipitation: precip,
          description: desc,
          prob30: p30,
          prob60: p60,
          prob90: p90,
        );
      }
    } catch (e) {
      debugPrint("Weather auto-sync failed: $e");
    }
  }

  // -------------------------------------------------------------
  // Mock Weather Feature (สำหรับการนำเสนอและทดสอบในวันที่ฝนไม่ตก)
  // -------------------------------------------------------------
  bool get isMockWeatherEnabled => WeatherService.isMockEnabled;
  Map<String, dynamic>? get mockWeatherData => WeatherService.mockWeatherData;

  Future<void> setMockWeatherPreset(String presetKey, {String? deviceId}) async {
    await WeatherService.setMockPreset(presetKey);
    await syncWeatherForecast(deviceId: deviceId, force: true);
    notifyListeners();
  }

  Future<void> setCustomMockWeather({
    required double temperature,
    required double precipitation,
    required String description,
    required String icon,
    required int prob30,
    int? prob60,
    int? prob90,
    String? deviceId,
  }) async {
    await WeatherService.setMockWeather(
      temperature: temperature,
      precipitation: precipitation,
      description: description,
      icon: icon,
      prob30: prob30,
      prob60: prob60 ?? (prob30 * 0.85).round(),
      prob90: prob90 ?? (prob30 * 0.70).round(),
    );
    await syncWeatherForecast(deviceId: deviceId, force: true);
    notifyListeners();
  }

  Future<void> disableMockWeather({String? deviceId}) async {
    await WeatherService.clearMock();
    await syncWeatherForecast(deviceId: deviceId, force: true);
    notifyListeners();
  }

  final List<AlertHistoryItem> _alertHistory = [];
  List<AlertHistoryItem> get alertHistory {
    final now = DateTime.now();
    return _alertHistory.where((item) => now.difference(item.time).inDays <= 7).toList();
  }

  // SOS Requests
  List<SosRequest> _sosRequests = [];
  List<SosRequest> get sosRequests => _sosRequests;
  int get pendingSosCount => _sosRequests.where((s) => s.status == 'pending').length;

  Timer? _heartbeatTimer;
  final Map<String, DateTime> _deviceLastReceived = {};
  final Map<String, String> _lastKnownDevicePayloads = {};
  final Map<String, List<Map<String, dynamic>>> _deviceSampleHistory = {};
  bool _hasManuallySelectedDevice = false;
  final Map<String, int> _lastSnapshotTimeMs = {};
  final Map<String, double> _lastSnapshotWaterLevel = {};

  static DatabaseReference? _tryGetDbRef() {
    try {
      return FirebaseDatabase.instance.ref();
    } catch (_) {
      return null;
    }
  }

  SensorProvider({DatabaseReference? dbRef}) : _dbRef = dbRef ?? _tryGetDbRef() {
    WeatherService.initMockState();
    _loadAlertHistory();
    _loadDeletedDeviceIds();
    _initMockDevices();
    if (_dbRef != null) {
      _initFirebaseListener();
      _initSosListener();
    }
    _startHistoryTimer();
    _startHeartbeatTimer();
    _startAutoLogTimer();
    _startWeatherSyncTimer();
  }

  Timer? _autoLogTimer;
  final Map<String, StreamSubscription<DatabaseEvent>> _historySubscriptions = {};

  void _startAutoLogTimer() {
    _autoLogTimer?.cancel();
    // 24/7 continuous automatic logging from active IoT devices
    _autoLogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      for (var entry in _devices.entries) {
        _maybeRecordHistorySnapshot(entry.key, entry.value);
      }
    });
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_devices.isNotEmpty) {
        notifyListeners();
      }
    });
  }

  void _initSosListener() {
    try {
      if (_dbRef == null) return;
      _dbRef.child('sos_requests').onValue.listen((event) {
        try {
          if (!event.snapshot.exists || event.snapshot.value == null) {
            _sosRequests = [];
            notifyListeners();
            return;
          }
          final raw = event.snapshot.value;
          final List<SosRequest> loaded = [];
          if (raw is Map) {
            raw.forEach((key, val) {
              if (val is Map) {
                try {
                  loaded.add(SosRequest.fromJson(key.toString(), val));
                } catch (e) {
                  debugPrint("Error parsing SOS item $key: $e");
                }
              }
            });
          } else if (raw is List) {
            for (int i = 0; i < raw.length; i++) {
              final val = raw[i];
              if (val is Map) {
                try {
                  loaded.add(SosRequest.fromJson(i.toString(), val));
                } catch (e) {
                  debugPrint("Error parsing SOS list item $i: $e");
                }
              }
            }
          }
          loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _sosRequests = loaded;
          notifyListeners();
        } catch (e) {
          debugPrint("Error processing SOS snapshot: $e");
        }
      }, onError: (err) {
        debugPrint("Error in SOS listener stream: $err");
      });
    } catch (e) {
      debugPrint("Error in SOS listener: $e");
    }
  }

  Future<void> sendSosRequest({
    required String userName,
    required String phoneNumber,
    required double lat,
    required double lng,
    required String situation,
    String note = '',
    String nationalId = '',
    String dob = '',
    String nickname = '',
    String englishName = '',
  }) async {
    final now = DateTime.now();
    final String id = now.millisecondsSinceEpoch.toString();
    final item = SosRequest(
      id: id,
      userName: userName,
      phoneNumber: phoneNumber,
      lat: lat,
      lng: lng,
      situation: situation,
      note: note,
      status: 'pending',
      timestamp: now,
      nationalId: nationalId,
      dob: dob,
      nickname: nickname,
      englishName: englishName,
    );

    // Optimistic local update so it shows immediately
    _sosRequests.removeWhere((s) => s.id == item.id);
    _sosRequests.insert(0, item);
    notifyListeners();

    if (_dbRef != null) {
      try {
        final newRef = _dbRef.child('sos_requests').push();
        final actualId = newRef.key ?? id;
        await newRef.set(item.toJson());
        // Write entry to notification queue for backend trigger workers
        try {
          await _dbRef.child('sos_notifications_queue/$actualId').set({
            'sosId': actualId,
            'userName': userName,
            'phoneNumber': phoneNumber,
            'situation': situation,
            'note': note,
            'lat': lat,
            'lng': lng,
            'timestamp': now.toIso8601String(),
            'status': 'pending',
          });
        } catch (qErr) {
          debugPrint("Error writing to SOS notification queue: $qErr");
        }
      } catch (e) {
        debugPrint("Error sending SOS request to Firebase: $e");
      }
    }

    // Trigger urgent email alert to admin as immediate failsafe
    try {
      EmailOtpService.instance.sendUrgentSosEmailToAdmin(
        adminEmail: 'admin@admin.com',
        victimName: userName,
        situation: situation,
        phone: phoneNumber,
        note: note,
        coordinates: '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
      ).catchError((_) => false);
    } catch (_) {}
  }

  Future<void> updateSosStatus(String sosId, String newStatus) async {
    final index = _sosRequests.indexWhere((s) => s.id == sosId);
    if (index != -1) {
      final old = _sosRequests[index];
      _sosRequests[index] = SosRequest(
        id: old.id,
        userName: old.userName,
        phoneNumber: old.phoneNumber,
        lat: old.lat,
        lng: old.lng,
        situation: old.situation,
        note: old.note,
        status: newStatus,
        timestamp: old.timestamp,
        nationalId: old.nationalId,
        dob: old.dob,
        nickname: old.nickname,
        englishName: old.englishName,
      );
      notifyListeners();
    }
    if (_dbRef != null) {
      try {
        await _dbRef.child('sos_requests/$sosId/status').set(newStatus);
      } catch (e) {
        debugPrint("Error updating SOS status in Firebase: $e");
      }
    }
  }

  Future<void> updateDeviceCalibration(String deviceId, double sensorHeight) async {
    if (_devices.containsKey(deviceId)) {
      _devices[deviceId]!.sensorHeight = sensorHeight;
    }
    if (_dbRef != null) {
      await _dbRef.child('devices/$deviceId/sensorHeight').set(sensorHeight);
    }
    notifyListeners();
  }

  /// อัปเดตพิกัดตำแหน่งจริงของอุปกรณ์ IoT ขึ้น Firebase RTDB (เช่น การซิงค์พิกัดจาก GPS มือถือ)
  Future<void> updateDeviceLocation(String deviceId, double lat, double lng) async {
    if (_devices.containsKey(deviceId)) {
      _devices[deviceId]!.lat = lat;
      _devices[deviceId]!.lng = lng;
    }
    if (deviceId == 'device_1' && _devices.containsKey('station_upstream')) {
      _devices['station_upstream']!.lat = lat;
      _devices['station_upstream']!.lng = lng;
    }
    if (_dbRef != null) {
      await _dbRef.child('devices/$deviceId').update({
        'lat': lat,
        'lng': lng,
      });
    }
    // ดึงพยากรณ์อากาศใหม่ตามพิกัดใหม่ทันที
    syncWeatherForecast();
    notifyListeners();
  }

  String generateDailySummaryReport(String deviceId) {
    final device = _devices[deviceId] ?? currentDevice;
    if (device == null) return 'ไม่มีข้อมูลอุปกรณ์';

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} น.';

    final List<double> history = _deviceWaterLevelHistory[device.id] ?? [device.waterLevel];
    final double maxWl = history.reduce((a, b) => a > b ? a : b);
    final double minWl = history.reduce((a, b) => a < b ? a : b);
    final double avgWl = history.reduce((a, b) => a + b) / history.length;

    return '''
==========================================
📋 รายงานสรุปสถานการณ์น้ำ & เซนเซอร์ IoT
ระบบเตือนภัยน้ำท่วมเครือข่ายสถานีตรวจวัด GIS
==========================================
📅 วันที่ออกรายงาน: $dateStr
📍 สถานี: ${device.name}
🌐 พิกัด GIS: ${device.lat.toStringAsFixed(6)}, ${device.lng.toStringAsFixed(6)}

🌊 สถานะระดับน้ำ & แนวโน้ม:
- ระดับน้ำปัจจุบัน: ${device.waterLevel.toStringAsFixed(1)} ซม.
- ระดับน้ำสูงสุดในรอบสถิติ: ${maxWl.toStringAsFixed(1)} ซม.
- ระดับน้ำต่ำสุด: ${minWl.toStringAsFixed(1)} ซม.
- ระดับน้ำเฉลี่ย: ${avgWl.toStringAsFixed(1)} ซม.
- เกณฑ์ระดับวิกฤต: ${device.waterLevelThreshold.toStringAsFixed(1)} ซม.
- สถานะระบบ: ${device.systemStatus}
- อัตราการเปลี่ยนแปลง (RoC เซนเซอร์): ${device.risingSpeed >= 0 ? '+' : ''}${device.risingSpeed.toStringAsFixed(1)} ซม./ชม.
- ความเร็วคาดการณ์รวมฝน (Sensor Fusion): ${device.compoundRisingSpeed >= 0 ? '+' : ''}${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. (โอกาสฝน ${device.forecastRainProb30}%)
- ระดับเตือนภัยล่วงหน้า: ${device.smartEarlyWarningTitle}
- แนวโน้ม: ${device.trendStatusText}
- การคาดการณ์: ${device.compoundTimeToDangerText}

🏙️ การวิเคราะห์ระดับน้ำในเครือข่ายสถานี:
- ส่วนต่างระดับน้ำเปรียบเทียบ: ${waterLevelDelta >= 0 ? '+' : ''}${waterLevelDelta.toStringAsFixed(1)} ซม.
- สถานะเครือข่าย: $drainageStatusText
${hasProximityFloodAlert ? '- 🚨 การเตือนภัยในรัศมีใกล้เคียง: $proximityFloodAlertMessage\n' : ''}
🔋 สถานะฮาร์ดแวร์ & พลังงาน (Station Health):
- รุ่นบอร์ด: ${device.boardModel} (FW: ${device.firmware})
- สถานะการเชื่อมต่อ: ${device.isDeviceOnline ? 'ออนไลน์' : 'ออฟไลน์'}
- ระดับแบตเตอรี่: ${device.batteryPercent}% (${device.batteryVoltage.toStringAsFixed(1)}V)
- ความแรงสัญญาณ: ${device.signalPercent}% (${device.networkType})
- ความสูงติดตั้งเซนเซอร์ (Calibration Offset): ${device.sensorHeight.toStringAsFixed(1)} ซม.

🚨 ประวัติการเตือนภัยสะสม: ${_alertHistory.length} รายการ
==========================================
''';
  }

  Future<void> _loadAlertHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('alert_history');
    if (historyJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(historyJson);
        final List<AlertHistoryItem> loadedHistory = decodedList.map((item) => AlertHistoryItem.fromJson(item as Map<String, dynamic>)).toList();
        
        final now = DateTime.now();
        _alertHistory.clear();
        _alertHistory.addAll(loadedHistory.where((item) => now.difference(item.time).inDays <= 7));
        
        // Save cleaned history if any items were removed
        if (_alertHistory.length < loadedHistory.length) {
          _saveAlertHistory();
        }
        
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading alert history: $e");
      }
    }
  }

  Future<void> _saveAlertHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(_alertHistory.map((item) => item.toJson()).toList());
      await prefs.setString('alert_history', encodedData);
    } catch (e) {
      debugPrint("Error saving alert history: $e");
    }
  }

  Future<void> _loadDeletedDeviceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? ids = prefs.getStringList('deleted_device_ids');
      if (ids != null && ids.isNotEmpty) {
        _deletedDeviceIds.addAll(ids);
        bool removed = false;
        for (final id in ids) {
          if (_devices.containsKey(id)) {
            _devices.remove(id);
            removed = true;
          }
        }
        _devices.removeWhere((key, dev) => _deletedDeviceIds.contains(key) || _deletedDeviceIds.contains(dev.id));
        if (removed) {
          if (!_devices.containsKey(_selectedDeviceId)) {
            _selectedDeviceId = _devices.isNotEmpty ? _devices.keys.first : '';
          }
          _checkProximityFloodAlerts();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error loading deleted device ids: $e");
    }
  }

  Future<void> _saveDeletedDeviceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('deleted_device_ids', _deletedDeviceIds.toList());
    } catch (e) {
      debugPrint("Error saving deleted device ids: $e");
    }
  }

  void _startHistoryTimer() {
    _historyTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_devices.isNotEmpty) {
        _devices.forEach((id, device) {
          if (_dbRef == null || id == 'device_test') {
            final now = DateTime.now();
            device.lastSeen = now;
            device.lastDataReceived = now;
            _deviceLastReceived[id] = now;
          }
          _deviceWaterLevelHistory.putIfAbsent(id, () => List.filled(21, device.isDeviceOnline ? device.waterLevel : 0.0, growable: true));
          _deviceRainfallHistory.putIfAbsent(id, () => List.filled(21, device.isDeviceOnline ? device.rainfall : 0.0, growable: true));
          _deviceWaterFlowHistory.putIfAbsent(id, () => List.filled(21, device.isDeviceOnline ? device.waterFlow : 0.0, growable: true));

          final wlList = _deviceWaterLevelHistory[id]!;
          final rfList = _deviceRainfallHistory[id]!;
          final wfList = _deviceWaterFlowHistory[id]!;

          final double currentWl = device.isDeviceOnline ? device.waterLevel : 0.0;
          final double currentRf = device.isDeviceOnline ? device.rainfall : 0.0;
          final double currentWf = device.isDeviceOnline ? device.waterFlow : 0.0;

          wlList.add(currentWl);
          rfList.add(currentRf);
          wfList.add(currentWf);

          if (wlList.length > 21) {
            wlList.removeAt(0);
            rfList.removeAt(0);
            wfList.removeAt(0);
          }
        });
        notifyListeners();
      }
    });
  }

  void addNewDevice({
    required String id,
    required String name,
    required double lat,
    required double lng,
  }) {
    final newDevice = DeviceData(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      waterLevel: 0.0,
      waterFlow: 0.0,
      stationType: (id.contains('upstream') || id.contains('riverbank')) ? 'upstream' : 'downstream',
      rainfall: 0.0,
    );
    _devices[id] = newDevice;
    _deviceWaterLevelHistory[id] = List.filled(21, 0.0, growable: true);
    _deviceRainfallHistory[id] = List.filled(21, 0.0, growable: true);
    _deviceWaterFlowHistory[id] = List.filled(21, 5.0, growable: true);
    _deviceHistory24h[id] = _generateFallbackHistory(id, hours: 24);
    _deviceHistory7d[id] = _generateFallbackHistory(id, hours: 168);
    _selectedDeviceId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _historyTimer?.cancel();
    _autoLogTimer?.cancel();
    _weatherSyncTimer?.cancel();
    for (var sub in _historySubscriptions.values) {
      sub.cancel();
    }
    _historySubscriptions.clear();
    super.dispose();
  }

  List<double> get waterLevelHistory {
    final dev = currentDevice ?? (_devices.containsKey(_selectedDeviceId) ? _devices[_selectedDeviceId] : null);
    if (dev != null && !dev.isDeviceOnline) {
      // เมื่ออุปกรณ์ออฟไลน์ / ไม่ได้รับค่า ให้ส่งกราฟเป็น 0 ทันที ไม่ค้างที่ค่าล่าสุด
      return List.filled(21, 0.0);
    }
    if (_deviceWaterLevelHistory.containsKey(_selectedDeviceId)) {
      return _deviceWaterLevelHistory[_selectedDeviceId]!;
    }
    return List.filled(21, (dev != null && dev.isDeviceOnline) ? dev.waterLevel : 0.0, growable: true);
  }

  List<double> get rainfallHistory {
    final dev = currentDevice ?? (_devices.containsKey(_selectedDeviceId) ? _devices[_selectedDeviceId] : null);
    if (dev != null && !dev.isDeviceOnline) {
      return List.filled(21, 0.0);
    }
    if (_deviceRainfallHistory.containsKey(_selectedDeviceId)) {
      return _deviceRainfallHistory[_selectedDeviceId]!;
    }
    return List.filled(21, (dev != null && dev.isDeviceOnline) ? dev.rainfall : 0.0, growable: true);
  }

  List<double> get waterFlowHistory {
    final dev = currentDevice ?? (_devices.containsKey(_selectedDeviceId) ? _devices[_selectedDeviceId] : null);
    if (dev != null && !dev.isDeviceOnline) {
      return List.filled(21, 0.0);
    }
    if (_deviceWaterFlowHistory.containsKey(_selectedDeviceId)) {
      return _deviceWaterFlowHistory[_selectedDeviceId]!;
    }
    return List.filled(21, (dev != null && dev.isDeviceOnline) ? dev.waterFlow : 0.0, growable: true);
  }

  void _initMockDevices() {
    final upstreamData = DeviceData(
      id: 'station_upstream',
      name: 'สถานีตรวจวัด IoT (device_1 - ปากคลองผดุงฯ)',
      lat: 13.7563,
      lng: 100.5018,
      waterLevel: 5.0,
      waterFlow: 12.0,
      waterLevelThreshold: 30.0,
      stationType: 'upstream',
      batteryPercent: 92,
      batteryVoltage: 4.1,
      sensorHeight: 200.0,
      signalPercent: 88,
      signalRssi: -58,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'Upstream_IoT_2.4G',
      ipAddress: '192.168.1.104',
      hasWifiData: true,
    );
    final deviceTestData = DeviceData(
      id: 'device_test',
      name: 'อุปกรณ์ทดสอบ (device test)',
      lat: 13.7568,
      lng: 100.5028,
      waterLevel: 5.0,
      waterFlow: 7.0,
      waterLevelThreshold: 30.0,
      stationType: 'upstream',
      batteryPercent: 95,
      batteryVoltage: 4.18,
      sensorHeight: 200.0,
      signalPercent: 90,
      signalRssi: -52,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'Device_Test_AP',
      ipAddress: '192.168.1.199',
      hasWifiData: true,
    );
    final downstreamData = DeviceData(
      id: 'station_downstream',
      name: 'สถานีตรวจวัด IoT จุดที่ 2 (ประตูน้ำสามเสน)',
      lat: 13.7620,
      lng: 100.5120,
      waterLevel: 4.5,
      waterFlow: 6.0,
      waterLevelThreshold: 30.0,
      stationType: 'downstream',
      batteryPercent: 84,
      batteryVoltage: 3.9,
      sensorHeight: 180.0,
      signalPercent: 78,
      signalRssi: -62,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'Downstream_Flood_AP',
      ipAddress: '192.168.1.108',
      hasWifiData: true,
    );
    final bangsueData = DeviceData(
      id: 'station_bangsue',
      name: 'สถานีคลองบางซื่อ (Bangsue - รัศมี 6.0 กม.)',
      lat: 13.8050,
      lng: 100.5250,
      waterLevel: 6.0,
      waterFlow: 8.5,
      waterLevelThreshold: 30.0,
      stationType: 'network',
      batteryPercent: 89,
      batteryVoltage: 4.0,
      sensorHeight: 190.0,
      signalPercent: 85,
      signalRssi: -60,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'Bangsue_Station_IoT',
      ipAddress: '192.168.1.112',
      hasWifiData: true,
    );
    final bangkokNoiData = DeviceData(
      id: 'station_bangkoknoi',
      name: 'สถานีคลองบางกอกน้อย (Bangkok Noi - รัศมี 6.2 กม.)',
      lat: 13.7650,
      lng: 100.4450,
      waterLevel: 5.5,
      waterFlow: 7.0,
      waterLevelThreshold: 30.0,
      stationType: 'network',
      batteryPercent: 91,
      batteryVoltage: 4.1,
      sensorHeight: 185.0,
      signalPercent: 82,
      signalRssi: -64,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'BangkokNoi_IoT',
      ipAddress: '192.168.1.115',
      hasWifiData: true,
    );
    final saenSaepData = DeviceData(
      id: 'station_saensaep',
      name: 'สถานีคลองแสนแสบ (Saen Saep - รัศมี 8.7 กม.)',
      lat: 13.7480,
      lng: 100.5820,
      waterLevel: 6.0,
      waterFlow: 9.0,
      waterLevelThreshold: 30.0,
      stationType: 'network',
      batteryPercent: 86,
      batteryVoltage: 3.95,
      sensorHeight: 195.0,
      signalPercent: 80,
      signalRssi: -65,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'SaenSaep_AP',
      ipAddress: '192.168.1.120',
      hasWifiData: true,
    );
    final rama5Data = DeviceData(
      id: 'station_rama5',
      name: 'สถานีสะพานพระราม 5 (Rama 5 - รัศมี 8.8 กม.)',
      lat: 13.8350,
      lng: 100.4900,
      waterLevel: 5.0,
      waterFlow: 10.0,
      waterLevelThreshold: 30.0,
      stationType: 'network',
      batteryPercent: 95,
      batteryVoltage: 4.2,
      sensorHeight: 210.0,
      signalPercent: 90,
      signalRssi: -55,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'Rama5_Bridge_IoT',
      ipAddress: '192.168.1.125',
      hasWifiData: true,
    );
    final phraPradaengData = DeviceData(
      id: 'station_phrapradaeng',
      name: 'สถานีพระประแดง (Phra Pradaeng - รัศมี 11.6 กม.)',
      lat: 13.6550,
      lng: 100.5300,
      waterLevel: 4.0,
      waterFlow: 5.0,
      waterLevelThreshold: 30.0,
      stationType: 'network',
      batteryPercent: 88,
      batteryVoltage: 4.0,
      sensorHeight: 175.0,
      signalPercent: 75,
      signalRssi: -68,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'PhraPradaeng_IoT',
      ipAddress: '192.168.1.130',
      hasWifiData: true,
    );
    final rangsitData = DeviceData(
      id: 'station_rangsit',
      name: 'สถานีประตูน้ำรังสิต (Rangsit - รัศมี 17.1 กม.)',
      lat: 13.9100,
      lng: 100.5150,
      waterLevel: 7.0,
      waterFlow: 14.0,
      waterLevelThreshold: 30.0,
      stationType: 'upstream',
      batteryPercent: 93,
      batteryVoltage: 4.15,
      sensorHeight: 220.0,
      signalPercent: 88,
      signalRssi: -58,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'Rangsit_Sluice_IoT',
      ipAddress: '192.168.1.140',
      hasWifiData: true,
    );

    final device1Data = DeviceData(
      id: 'device_1',
      name: 'สถานีตรวจวัด IoT (device_1 - ESP32 Gateway)',
      lat: 13.7563,
      lng: 100.5018,
      waterLevel: 5.0,
      waterFlow: 12.0,
      waterLevelThreshold: 30.0,
      stationType: 'upstream',
      batteryPercent: 92,
      batteryVoltage: 4.1,
      sensorHeight: 200.0,
      signalPercent: 88,
      signalRssi: -58,
      networkType: 'Wi-Fi (2.4 GHz)',
      wifiSsid: 'ESP32_Gateway_2.4G',
      ipAddress: '192.168.1.104',
      hasWifiData: true,
    );

    _devices = {
      'station_upstream': upstreamData,
      'device_1': device1Data,
      'device_test': deviceTestData,
      'station_downstream': downstreamData,
      'station_bangsue': bangsueData,
      'station_bangkoknoi': bangkokNoiData,
      'station_saensaep': saenSaepData,
      'station_rama5': rama5Data,
      'station_phrapradaeng': phraPradaengData,
      'station_rangsit': rangsitData,
    };

    if (_deletedDeviceIds.isNotEmpty) {
      _devices.removeWhere((key, dev) => _deletedDeviceIds.contains(key) || _deletedDeviceIds.contains(dev.id));
    }
    if (!_devices.containsKey(_selectedDeviceId)) {
      _selectedDeviceId = _devices.isNotEmpty ? _devices.keys.first : '';
    }

    final now = DateTime.now();
    for (final id in _devices.keys) {
      final dev = _devices[id]!;
      dev.lastSeen = now;
      dev.lastDataReceived = now;
      _deviceLastReceived[id] = now;
      _deviceHistory24h[id] = _generateFallbackHistory(id, hours: 24);
      _deviceHistory7d[id] = _generateFallbackHistory(id, hours: 168);
    }
    // Legacy mappings
    _deviceHistory24h['khlong_1'] = _deviceHistory24h['station_upstream']!;
    _deviceHistory7d['khlong_1'] = _deviceHistory7d['station_upstream']!;
    _deviceHistory24h['khlong_2'] = _deviceHistory24h['station_downstream']!;
    _deviceHistory7d['khlong_2'] = _deviceHistory7d['station_downstream']!;
  }

  void _initFirebaseListener() {
    try {
      if (_dbRef == null) return;
      _dbRef.child('devices').onValue.listen((event) {
        if (!event.snapshot.exists) {
          _initMockDevices();
          notifyListeners();
        } else {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          if (_devices.isEmpty) {
            _initMockDevices();
          }
          final Map<String, DeviceData> newDevices = Map.from(_devices);
          newDevices.removeWhere((key, dev) => _deletedDeviceIds.contains(key) || _deletedDeviceIds.contains(dev.id));
          data.forEach((key, value) {
            if (value is! Map) return;
            final String id = key.toString();
            if (_deletedDeviceIds.contains(id)) return;
            final Map<dynamic, dynamic> deviceData = value;
            
            // Safe type parsing for Firebase fields
            final double currentWaterLevel = (deviceData['waterLevel'] is num)
                ? (deviceData['waterLevel'] as num).toDouble()
                : (double.tryParse(deviceData['waterLevel']?.toString() ?? '') ?? 0.0);

            final double currentWaterFlow = (deviceData['waterFlow'] is num)
                ? (deviceData['waterFlow'] as num).toDouble()
                : (double.tryParse(deviceData['waterFlow']?.toString() ?? '') ?? 5.0);

            final double currentRainfall = (deviceData['rainfall'] is num)
                ? (deviceData['rainfall'] as num).toDouble()
                : (double.tryParse(deviceData['rainfall']?.toString() ?? '') ?? 0.0);


            bool isOnline = true;
            final rawOnline = deviceData['isOnline'];
            if (rawOnline is bool) {
              isOnline = rawOnline;
            } else if (rawOnline is num) {
              isOnline = rawOnline != 0;
            } else if (rawOnline is String) {
              isOnline = rawOnline.toLowerCase() == 'true' || rawOnline == '1' || rawOnline.toLowerCase() == 'online';
            }

            final int currentBatteryPercent = (deviceData['batteryPercent'] is num)
                ? (deviceData['batteryPercent'] as num).toInt()
                : (int.tryParse(deviceData['batteryPercent']?.toString() ?? '') ?? 85);

            final double currentBatteryVoltage = (deviceData['batteryVoltage'] is num)
                ? (deviceData['batteryVoltage'] as num).toDouble()
                : (double.tryParse(deviceData['batteryVoltage']?.toString() ?? '') ?? 3.9);

            final double currentSensorHeight = (deviceData['sensorHeight'] is num)
                ? (deviceData['sensorHeight'] as num).toDouble()
                : (double.tryParse(deviceData['sensorHeight']?.toString() ?? '') ?? 200.0);

            // Calculate Rate of Change (RoC) directly in App from sensor samples
            double calculatedRisingSpeed = 0.0;
            if (deviceData['risingSpeed'] is num) {
              calculatedRisingSpeed = (deviceData['risingSpeed'] as num).toDouble();
            } else if (deviceData['rateOfRise3Min'] is num) {
              calculatedRisingSpeed = (deviceData['rateOfRise3Min'] as num).toDouble() * 20.0;
            } else {
              _deviceSampleHistory.putIfAbsent(id, () => []);
              final sampleList = _deviceSampleHistory[id]!;
              final nowSample = DateTime.now();
              sampleList.add({'time': nowSample, 'level': currentWaterLevel});
              sampleList.removeWhere((s) => nowSample.difference(s['time'] as DateTime).inSeconds > 120);
              if (sampleList.length > 20) {
                sampleList.removeAt(0);
              }

              if (sampleList.length >= 2) {
                final oldest = sampleList.first;
                final int secDiff = nowSample.difference(oldest['time'] as DateTime).inSeconds;
                if (secDiff >= 5) {
                  final double levelDiff = currentWaterLevel - (oldest['level'] as double);
                  final double rawSpeedPerHour = levelDiff / (secDiff / 3600.0);
                  final double previousSpeed = _devices[id]?.risingSpeed ?? 0.0;
                  // Low-pass exponential smoothing filter
                  calculatedRisingSpeed = (0.7 * previousSpeed) + (0.3 * rawSpeedPerHour);
                  if (calculatedRisingSpeed.abs() < 0.2) calculatedRisingSpeed = 0.0;
                  calculatedRisingSpeed = double.parse(calculatedRisingSpeed.toStringAsFixed(1));
                } else {
                  calculatedRisingSpeed = _devices[id]?.risingSpeed ?? 0.0;
                }
              } else if (_devices.containsKey(id)) {
                final previousWaterLevel = _devices[id]!.waterLevel;
                final double difference = currentWaterLevel - previousWaterLevel;
                if (difference > 0) {
                  calculatedRisingSpeed = difference * (60.0 / 5.0);
                } else if (difference == 0) {
                  calculatedRisingSpeed = _devices[id]!.risingSpeed * 0.5;
                }
              }
            }

            DateTime? lastSeen;
            final dynamic rawTs = deviceData['timestamp'] ??
                deviceData['lastSeen'] ??
                deviceData['last_seen'] ??
                deviceData['updatedAt'] ??
                deviceData['lastUpdate'] ??
                deviceData['time'];
            if (rawTs != null) {
              lastSeen = _parseTimestamp(rawTs);
            }

            // Track packet arrival per device accurately
            final dynamic rawWater = deviceData['waterLevel'];
            final dynamic sigRssi = deviceData['rssi'] ?? deviceData['wifi_rssi'] ?? deviceData['signalRssi'];
            final dynamic rawDist = deviceData['distance'];
            final dynamic rawPing = deviceData['pingMs'] ?? deviceData['ping'];
            final String currentSig = '$rawWater|$sigRssi|$rawDist|$rawTs|$rawPing|${deviceData['wifi']}';

            final bool isFirstTime = !_lastKnownDevicePayloads.containsKey(id);
            final bool hasChanged = !isFirstTime && _lastKnownDevicePayloads[id] != currentSig;
            _lastKnownDevicePayloads[id] = currentSig;

            if (isFirstTime) {
              if (lastSeen != null) {
                final int ageSec = DateTime.now().difference(lastSeen).inSeconds;
                if (ageSec >= 0 && ageSec <= DeviceData.offlineTimeoutSeconds) {
                  _deviceLastReceived[id] = DateTime.now();
                } else {
                  // ข้อมูลเก่าเกินกำหนด (เช่น เซนเซอร์ถูกถอดออกก่อนเปิดแอป) ให้ถือเป็นออฟไลน์ทันที
                  _deviceLastReceived[id] = lastSeen;
                }
              } else {
                // ไม่มี timestamp ในข้อมูล: ไม่เดาเวลา ให้รอรับ packet แรกจริง
                _deviceLastReceived.remove(id);
              }
            } else if (hasChanged || (lastSeen != null && _devices[id]?.lastSeen != null && lastSeen != _devices[id]!.lastSeen)) {
              // ตรวจพบข้อมูลสดส่งมาจาก ESP32 จริงๆ
              _deviceLastReceived[id] = DateTime.now();
            }


            bool hasWater = true;
            final rawHasWater = deviceData['hasWaterLevelSensor'] ??
                deviceData['hasWaterSensor'] ??
                deviceData['isWaterSensorInstalled'];
            if (rawHasWater is bool) {
              hasWater = rawHasWater;
            } else if (rawHasWater is num) {
              hasWater = rawHasWater != 0;
            } else if (rawHasWater is String) {
              hasWater = rawHasWater.toLowerCase() == 'true' || rawHasWater == '1';
            } else if (deviceData['modules'] is Map && (deviceData['modules'] as Map).containsKey('ultrasonic')) {
              final uMod = (deviceData['modules'] as Map)['ultrasonic'];
              if (uMod is Map && uMod.containsKey('installed')) {
                hasWater = uMod['installed'] == true;
              }
            }

            final bool rainingHeavy = currentRainfall > 20.0;

            Map<String, dynamic> modules = {};
            if (deviceData['modules'] is Map) {
              (deviceData['modules'] as Map).forEach((k, v) {
                if (v is Map) {
                  modules[k.toString()] = Map<String, dynamic>.from(v);
                }
              });
            }

            // --- Parse Real Wi-Fi & RSSI Telemetry ---
            int? parsedRssi;
            final rawRssi = deviceData['rssi'] ??
                deviceData['wifi_rssi'] ??
                deviceData['wifiRssi'] ??
                deviceData['signalRssi'] ??
                deviceData['signal_rssi'] ??
                deviceData['signalStrength'];
            if (rawRssi != null) {
              if (rawRssi is num) {
                parsedRssi = rawRssi.toInt();
              } else if (rawRssi is String) {
                final clean = rawRssi.replaceAll('dBm', '').trim();
                parsedRssi = int.tryParse(clean);
              }
            }

            int? parsedPercent;
            final rawPercent = deviceData['signalPercent'] ??
                deviceData['signal_percent'] ??
                deviceData['wifi'] ??
                deviceData['wifi_signal'] ??
                deviceData['wifiSignal'] ??
                deviceData['signal'] ??
                deviceData['wifiPercent'];
            if (rawPercent != null) {
              if (rawPercent is num) {
                parsedPercent = rawPercent.toInt().clamp(0, 100);
              } else if (rawPercent is String) {
                final clean = rawPercent.replaceAll('%', '').trim();
                final v = int.tryParse(clean);
                if (v != null) parsedPercent = v.clamp(0, 100);
              }
            }

            final String? parsedSsid = (deviceData['ssid'] ??
                deviceData['wifi_ssid'] ??
                deviceData['wifiSsid'] ??
                deviceData['wifiName'])?.toString().trim();

            final String? parsedIp = (deviceData['ip'] ??
                deviceData['ipAddress'] ??
                deviceData['ip_address'] ??
                deviceData['localIP'] ??
                deviceData['wifi_ip'])?.toString().trim();

            final int? parsedPing = (deviceData['pingMs'] is num)
                ? (deviceData['pingMs'] as num).toInt()
                : (int.tryParse(deviceData['ping']?.toString() ?? '') ??
                    ((deviceData['ping_ms'] is num) ? (deviceData['ping_ms'] as num).toInt() : null));

            // Accurate Wi-Fi RSSI to % Formula
            int finalPercent;
            int finalRssi;
            bool hasWifiData = false;

            if (parsedRssi != null) {
              hasWifiData = true;
              finalRssi = parsedRssi;
              if (parsedPercent != null) {
                finalPercent = parsedPercent;
              } else {
                if (finalRssi <= -100) {
                  finalPercent = 0;
                } else if (finalRssi >= -50) {
                  finalPercent = 100;
                } else {
                  // Standard formula: 2 * (RSSI + 100)
                  finalPercent = (2 * (finalRssi + 100)).clamp(0, 100);
                }
              }
            } else if (parsedPercent != null) {
              hasWifiData = true;
              finalPercent = parsedPercent;
              finalRssi = (-100 + (finalPercent / 2)).round();
            } else {
              // Hardware didn't explicitly send Wi-Fi keys:
              // If connected and sending packets, provide standard connection estimate
              hasWifiData = false;
              finalPercent = 75;
              finalRssi = -65;
            }

            final String networkType = deviceData['networkType']?.toString() ??
                (parsedSsid != null ? 'Wi-Fi ($parsedSsid)' : 'Wi-Fi (2.4 GHz)');

            final existingDev = _devices[id];
            final int fProb30 = existingDev?.forecastRainProb30 ?? 20;
            final int fProb60 = existingDev?.forecastRainProb60 ?? 30;
            final int fProb90 = existingDev?.forecastRainProb90 ?? 15;

            final bool isMock = WeatherService.isMockEnabled && WeatherService.mockWeatherData != null;
            final double mockRainfall = isMock
                ? ((WeatherService.mockWeatherData!['precipitation'] ?? 0.0) as num).toDouble()
                : 0.0;
            final int mockP30 = isMock ? (WeatherService.mockWeatherData!['prob30'] ?? 20) as int : 20;
            final int mockP60 = isMock ? (WeatherService.mockWeatherData!['prob60'] ?? 30) as int : 30;
            final int mockP90 = isMock ? (WeatherService.mockWeatherData!['prob90'] ?? 15) as int : 15;
            final String mockWeatherStatus = isMock ? (WeatherService.mockWeatherData!['description']?.toString() ?? 'ปกติ') : 'ปกติ';

            final double effectiveRainfall = isMock ? mockRainfall : currentRainfall;
            final String effectiveWeatherStatus = isMock ? mockWeatherStatus : (deviceData['weatherStatus']?.toString() ?? 'ปกติ');
            final int effectiveProb30 = isMock ? mockP30 : fProb30;
            final int effectiveProb60 = isMock ? mockP60 : fProb60;
            final int effectiveProb90 = isMock ? mockP90 : fProb90;
            final bool effectiveRainingHeavy = isMock
                ? (mockRainfall >= 20.0 || mockP30 >= 75)
                : rainingHeavy;

            final String sType = deviceData['stationType']?.toString() ??
                (id.contains('upstream') || id.contains('riverbank') || id.contains('khlong_1') || id == 'device_1' ? 'upstream' : 'downstream');

            final bool isGpsLocked = (deviceData['gpsLocked'] is bool)
                ? deviceData['gpsLocked'] as bool
                : (deviceData['gpsLocked']?.toString().toLowerCase() == 'true');

            newDevices[id] = DeviceData(
              id: id,
              name: deviceData['name']?.toString() ?? (id == 'device_1' ? 'สถานีตรวจวัด IoT (ESP32)' : 'Device $id'),
              lat: (deviceData['lat'] is num) ? (deviceData['lat'] as num).toDouble() : (double.tryParse(deviceData['lat']?.toString() ?? '') ?? 13.7563),
              lng: (deviceData['lng'] is num) ? (deviceData['lng'] as num).toDouble() : (double.tryParse(deviceData['lng']?.toString() ?? '') ?? 100.5018),
              waterLevel: currentWaterLevel,
              waterFlow: currentWaterFlow,
              rainfall: effectiveRainfall,
              weatherStatus: effectiveWeatherStatus,
              waterLevelThreshold: (deviceData['waterLevelThreshold'] is num) ? (deviceData['waterLevelThreshold'] as num).toDouble() : 50.0,
              stationType: sType,
              risingSpeed: calculatedRisingSpeed,
              isRainingHeavy: effectiveRainingHeavy,
              forecastRainProb30: effectiveProb30,
              forecastRainProb60: effectiveProb60,
              forecastRainProb90: effectiveProb90,
              signalPercent: finalPercent,
              signalRssi: finalRssi,
              networkType: networkType,
              pingMs: parsedPing ?? 24,
              wifiSsid: parsedSsid,
              ipAddress: parsedIp,
              hasWifiData: hasWifiData,
              batteryPercent: currentBatteryPercent,
              batteryVoltage: currentBatteryVoltage,
              sensorHeight: currentSensorHeight,
              isOnline: isOnline,
              hasWaterLevelSensor: hasWater,
              isGpsLocked: isGpsLocked,
              lastSeen: lastSeen,
              lastDataReceived: _deviceLastReceived[id],
              boardModel: deviceData['boardModel']?.toString() ?? 'ESP32-WROOM-32',
              firmware: deviceData['firmware']?.toString() ?? 'v2.0-auto',
              modules: modules,
            );
          });
          // If hardware sent 'device_1', keep station_upstream alias updated if not deleted
          if (newDevices.containsKey('device_1') && !data.containsKey('station_upstream') && !_deletedDeviceIds.contains('station_upstream')) {
            newDevices['station_upstream'] = newDevices['device_1']!;
          }
          newDevices.removeWhere((key, dev) => _deletedDeviceIds.contains(key) || _deletedDeviceIds.contains(dev.id));
          _devices.clear();
          _devices.addAll(newDevices);
        }
          // Smart Station Selection:
          // 1. If currently selected device is not in list, auto-select the online sensor
          if (!_devices.containsKey(_selectedDeviceId)) {
            final activeDev = _devices.values.where((d) => d.isDeviceOnline).firstOrNull ??
                (_devices.isNotEmpty ? _devices.values.first : null);
            _selectedDeviceId = activeDev?.id ?? '';
            _hasManuallySelectedDevice = false;
          } 
          // 2. If user hasn't explicitly chosen a station yet, and current selected is offline while a physical sensor is online, lock onto the online sensor
          else if (!_hasManuallySelectedDevice && !_devices[_selectedDeviceId]!.isDeviceOnline && _devices.values.any((d) => d.isDeviceOnline)) {
            final activeDev = _devices.values.firstWhere((d) => d.isDeviceOnline);
            _selectedDeviceId = activeDev.id;
          }
          
          _isFirebaseInitialized = true;
          _checkAndTriggerNotifications();
          notifyListeners();
          
          for (var id in _devices.keys) {
            final dev = _devices[id];
            if (dev != null) {
              _maybeRecordHistorySnapshot(id, dev);
            }
            if (!_historyFetchedDeviceIds.contains(id)) {
              fetchDeviceHistory(id);
            }
          }
      });
    } catch (e) {
      debugPrint("Firebase not configured yet: $e");
    }
  }

  DateTime? _parseTimestamp(dynamic rawTs) {
    if (rawTs == null) return null;
    if (rawTs is num) {
      int ts = rawTs.toInt();
      // If ts is Unix seconds (around 10 digits), convert to milliseconds
      if (ts > 0 && ts < 10000000000) {
        ts *= 1000;
      }
      if (ts > 0) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } else if (rawTs is String) {
      final int? parsedInt = int.tryParse(rawTs);
      if (parsedInt != null) {
        int ts = parsedInt;
        if (ts > 0 && ts < 10000000000) ts *= 1000;
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
      return DateTime.tryParse(rawTs);
    }
    return null;
  }

  Future<void> setDeviceOnlineStatus(String deviceId, bool online) async {
    try {
      if (_dbRef != null) {
        await _dbRef.child('devices/$deviceId/isOnline').set(online);
      }
      if (_devices.containsKey(deviceId)) {
        _devices[deviceId]!.isOnline = online;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error setting device online status: $e');
    }
  }

  Future<void> toggleCurrentSensorInstalled(String deviceId, bool installed) async {
    // Current sensor and leakage measurement removed from system
  }

  Future<void> toggleWaterLevelSensorInstalled(String deviceId, bool installed) async {
    try {
      if (_dbRef != null) {
        await _dbRef.child('devices/$deviceId/hasWaterLevelSensor').set(installed);
      }
      if (_devices.containsKey(deviceId)) {
        _devices[deviceId]!.hasWaterLevelSensor = installed;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling water level sensor: $e');
    }
  }

  Map<String, DeviceData> get devices => _devices;
  String get selectedDeviceId => _selectedDeviceId;

  /// รายการอุปกรณ์แบบไม่ซ้ำ ID (Deduplicated unique device list)
  List<DeviceData> get uniqueDeviceList {
    final Map<String, DeviceData> unique = {};
    for (final dev in _devices.values) {
      if (!_deletedDeviceIds.contains(dev.id)) {
        unique[dev.id] = dev;
      }
    }
    return unique.values.toList();
  }

  DeviceData? get currentDevice =>
      _devices[_selectedDeviceId] ??
      _devices.values.where((d) => d.id == _selectedDeviceId).firstOrNull ??
      (_devices.isNotEmpty ? _devices.values.first : null);

  // Dual-Station Getters & Comparative Analytics
  DeviceData? get upstreamDevice =>
      _devices['station_upstream'] ??
      _devices['station_riverbank'] ??
      _devices.values.firstWhere((d) => d.isUpstream, orElse: () => _devices.values.first);

  DeviceData? get downstreamDevice =>
      _devices['station_downstream'] ??
      _devices['station_urban'] ??
      _devices.values.firstWhere((d) => d.isDownstream, orElse: () => _devices.values.last);

  // Backward compatibility getters
  DeviceData? get riverbankDevice => upstreamDevice;
  DeviceData? get urbanDevice => downstreamDevice;

  /// ส่วนต่างระดับน้ำเปรียบเทียบระหว่าง 2 สถานี (ซม.)
  double get waterLevelDelta {
    final dev1 = upstreamDevice ?? currentDevice;
    final dev2 = downstreamDevice;
    if (dev1 == null || dev2 == null) return 0.0;
    return double.parse((dev1.waterLevel - dev2.waterLevel).toStringAsFixed(1));
  }

  /// คำอธิบายความต่างระดับน้ำแบบกระชับ (ระดับต่างกันแค่ไหน)
  String get deltaDescription {
    final dev1 = upstreamDevice ?? currentDevice;
    final dev2 = downstreamDevice;
    if (dev1 == null || dev2 == null) return 'ข้อมูลไม่เพียงพอ';
    final delta = waterLevelDelta;
    if (delta.abs() < 0.5) {
      return 'ระดับน้ำทั้งสองสถานีเท่ากัน';
    } else if (delta > 0) {
      return 'สถานีที่ 1 สูงกว่าสถานีที่ 2 ${delta.toStringAsFixed(1)} ซม.';
    } else {
      return 'สถานีที่ 2 สูงกว่าสถานีที่ 1 ${(-delta).toStringAsFixed(1)} ซม.';
    }
  }

  /// สภาวะปัจจุบันแบบกระชับ (อยู่ในสภาวะใด)
  String get drainageConditionShort {
    final dev1 = upstreamDevice ?? currentDevice;
    final dev2 = downstreamDevice;
    if (dev1 == null || dev2 == null) return 'ปกติ';

    final bool d1Danger = dev1.isFloodDanger || dev1.waterLevel >= dev1.waterLevelThreshold;
    final bool d2Danger = dev2.isFloodDanger || dev2.waterLevel >= dev2.waterLevelThreshold;

    if (d1Danger && d2Danger) {
      return 'วิกฤตน้ำท่วมทั้งสองสถานี';
    } else if (d1Danger && !d2Danger) {
      return '🚨 เตือนภัยวิกฤต! ตรวจพบระดับน้ำสูงที่ ${dev1.name}';
    } else if (!d1Danger && d2Danger) {
      return '⚠️ เตือนภัยวิกฤต! ตรวจพบระดับน้ำสูงที่ ${dev2.name}';
    } else if (dev1.waterLevel >= 40.0 && dev2.waterLevel < 25.0) {
      return 'เตือนภัยล่วงหน้า! ระดับน้ำในพื้นที่เริ่มสูงขึ้น';
    } else if (dev1.waterLevel > dev2.waterLevel + 15) {
      return 'เฝ้าระวังระดับน้ำเพิ่มสูงในเครือข่าย';
    } else {
      return 'ระดับน้ำในเครือข่ายสถานีปกติ';
    }
  }

  /// สถานะการระบายน้ำระหว่าง 2 จุด
  String get drainageStatusText => drainageConditionShort;

  Color get drainageStatusColor {
    final up = upstreamDevice;
    final down = downstreamDevice;
    if (up == null || down == null) return Colors.grey;
    if ((up.isFloodDanger || up.waterLevel >= up.waterLevelThreshold) &&
        (down.isFloodDanger || down.waterLevel >= down.waterLevelThreshold)) {
      return Colors.red;
    }
    if (up.isFloodDanger || up.waterLevel >= up.waterLevelThreshold) {
      return Colors.deepOrange;
    }
    if (down.isFloodDanger || down.waterLevel >= down.waterLevelThreshold) {
      return Colors.amber.shade800;
    }
    return Colors.green;
  }

  IconData get drainageStatusIcon {
    final up = upstreamDevice;
    final down = downstreamDevice;
    if (up == null || down == null) return Icons.help_outline_rounded;
    if ((up.isFloodDanger || up.waterLevel >= up.waterLevelThreshold) &&
        (down.isFloodDanger || down.waterLevel >= down.waterLevelThreshold)) {
      return Icons.crisis_alert_rounded;
    }
    if (up.isFloodDanger || up.waterLevel >= up.waterLevelThreshold) {
      return Icons.warning_amber_rounded;
    }
    if (down.isFloodDanger || down.waterLevel >= down.waterLevelThreshold) {
      return Icons.water_damage_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  // Shorthands for backward compatibility / easy access in views
  double get waterLevel => currentDevice?.waterLevel ?? 0.0;
  double get waterFlow => currentDevice?.waterFlow ?? 0.0;
  String get waterFlowStatus => currentDevice?.waterFlowStatus ?? 'นิ่ง';
  bool get isElectricalLeakage => false; // ตัดการวัดกระแสไฟออกแล้ว
  double get leakageProbability => 0.0;
  String get weatherStatus => currentDevice?.weatherStatus ?? 'ปกติ';
  double get rainfall => currentDevice?.rainfall ?? 0.0;
  double get waterLevelThreshold => currentDevice?.waterLevelThreshold ?? 50.0;
  double get risingSpeed => currentDevice?.risingSpeed ?? 0.0;
  bool get isRainingHeavy => currentDevice?.isRainingHeavy ?? false;
  bool get isFloodEmergency => currentDevice?.isFloodEmergency ?? false;
  bool get isFloodDanger => currentDevice?.isFloodDanger ?? false;
  bool get isFloodWarning => currentDevice?.isFloodWarning ?? false;
  bool get isEarlyWarning => currentDevice?.isEarlyWarning ?? false;
  double get sensorDistance => currentDevice?.sensorDistance ?? 100.0;
  String get hazardStateText => currentDevice?.hazardStateText ?? 'ปกติ (Normal)';
  String get hardwareStatusText => currentDevice?.hardwareStatusText ?? '🟢 ไฟเขียวติด • 🔇 Buzzer เงียบ';
  bool get isHardwareBuzzerActive => currentDevice?.isHardwareBuzzerActive ?? false;
  String get trafficImpactText => currentDevice?.trafficImpactText ?? 'ถนนแห้ง หรือน้ำขังตื้นๆ รถทุกชนิด (รถเก๋ง, มอเตอร์ไซค์, รถใหญ่) วิ่งผ่านได้สะดวก';
  double get compoundRisingSpeed => currentDevice?.compoundRisingSpeed ?? 0.0;
  EarlyWarningSeverity get earlyWarningSeverity => currentDevice?.earlyWarningSeverity ?? EarlyWarningSeverity.none;
  String get smartEarlyWarningTitle => currentDevice?.smartEarlyWarningTitle ?? 'สภาวะระดับน้ำปกติ';
  String get smartEarlyWarningBannerText => currentDevice?.smartEarlyWarningBannerText ?? '';
  String get compoundTimeToDangerText => currentDevice?.compoundTimeToDangerText ?? '';
  int get forecastRainProb30 => currentDevice?.forecastRainProb30 ?? 20;
  int get forecastRainProb60 => currentDevice?.forecastRainProb60 ?? 30;
  int get forecastRainProb90 => currentDevice?.forecastRainProb90 ?? 15;
  double get predictedWaterLevel30 => currentDevice?.predictedWaterLevel30 ?? 0.0;
  double get predictedWaterLevel60 => currentDevice?.predictedWaterLevel60 ?? 0.0;
  int get floodRiskProbability30 => currentDevice?.floodRiskProbability30 ?? 0;
  int get floodRiskProbability60 => currentDevice?.floodRiskProbability60 ?? 0;
  FloodWarningLevel get predictedWarningLevel30 => currentDevice?.predictedWarningLevel30 ?? FloodWarningLevel.safe;
  FloodWarningLevel get predictedWarningLevel60 => currentDevice?.predictedWarningLevel60 ?? FloodWarningLevel.safe;
  String get proactiveForecastSummary => currentDevice?.proactiveForecastSummary ?? 'ไม่มีข้อมูลอุปกรณ์';
  FloodWarningLevel get floodWarningLevel => currentDevice?.floodWarningLevel ?? FloodWarningLevel.safe;
  String get systemStatus {
    if (!isDeviceOnline) return 'อุปกรณ์กำลัง Offline';
    return currentDevice?.systemStatus ?? 'รอข้อมูล...';
  }
  bool get isDeviceOnline => currentDevice?.isDeviceOnline ?? false;

  void selectDevice(String deviceId) {
    if (_devices.containsKey(deviceId)) {
      final oldId = _selectedDeviceId;
      _selectedDeviceId = _devices[deviceId]!.id;
      _hasManuallySelectedDevice = true;
      if (!_historyFetchedDeviceIds.contains(_selectedDeviceId)) {
        fetchDeviceHistory(_selectedDeviceId);
      }
      if (oldId != _selectedDeviceId) {
        syncWeatherForecast(deviceId: _selectedDeviceId);
      }
      notifyListeners();
    } else {
      final found = _devices.values.where((d) => d.id == deviceId).firstOrNull;
      if (found != null) {
        _selectedDeviceId = found.id;
        _hasManuallySelectedDevice = true;
        if (!_historyFetchedDeviceIds.contains(_selectedDeviceId)) {
          fetchDeviceHistory(_selectedDeviceId);
        }
        notifyListeners();
      }
    }
  }

  /// ลบอุปกรณ์ออกจากระบบ (ลบจากหน่วยความจำ, บันทึกสถานะการลบถาวร, และลบจาก Firebase RTDB)
  Future<void> deleteDevice(String deviceId) async {
    _deletedDeviceIds.add(deviceId);
    
    // Remove from in-memory map by key and device ID
    _devices.remove(deviceId);
    _devices.removeWhere((key, dev) => dev.id == deviceId || key == deviceId);

    // Clean up caches & histories
    _deviceWaterLevelHistory.remove(deviceId);
    _deviceRainfallHistory.remove(deviceId);
    _deviceWaterFlowHistory.remove(deviceId);
    _deviceHistory24h.remove(deviceId);
    _deviceHistory7d.remove(deviceId);
    _deviceSampleHistory.remove(deviceId);
    _deviceLastReceived.remove(deviceId);
    _lastKnownDevicePayloads.remove(deviceId);
    _deviceProximityFloodAlerts.remove(deviceId);
    _notifiedProximityPairs.removeWhere((pair) => pair.contains(deviceId));

    // Update selected station if the deleted one was selected
    if (_selectedDeviceId == deviceId || !_devices.containsKey(_selectedDeviceId)) {
      _selectedDeviceId = _devices.isNotEmpty ? _devices.keys.first : '';
      _hasManuallySelectedDevice = false;
    }

    _checkProximityFloodAlerts();
    notifyListeners();

    // Persist deleted IDs to SharedPreferences
    await _saveDeletedDeviceIds();

    // Remove from Firebase Realtime Database
    if (_dbRef != null) {
      try {
        await _dbRef.child('devices/$deviceId').remove();
      } catch (e) {
        debugPrint("Error removing device $deviceId from Firebase: $e");
      }
    }
  }

  /// คืนค่าอุปกรณ์เริ่มต้นทั้งหมดที่ถูกลบไป
  Future<void> restoreAllDevices() async {
    _deletedDeviceIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('deleted_device_ids');
    } catch (e) {
      debugPrint("Error clearing deleted device ids from SharedPreferences: $e");
    }
    _initMockDevices();
    _checkProximityFloodAlerts();
    notifyListeners();
  }

  // Used by Simulator Screen
  void simulateDataFromIoT({
    required String deviceId,
    required double lat,
    required double lng,
    required double waterLevel,
    required double waterFlow,
    bool isLeakage = false,
    required double rainfall,
    bool isOnline = true,
  }) {
    if (!_devices.containsKey(deviceId)) {
      _devices[deviceId] = DeviceData(id: deviceId, name: 'Device $deviceId', lat: lat, lng: lng);
    }
    final device = _devices[deviceId]!;

    final double diff = waterLevel - device.waterLevel;
    if (diff > 0) {
      device.risingSpeed = diff * (60.0 / 5.0);
    } else if (diff < 0) {
      device.risingSpeed = 0.0;
    }

    device.lat = lat;
    device.lng = lng;
    device.waterLevel = waterLevel;
    device.waterFlow = waterFlow;
    device.rainfall = rainfall;
    device.isRainingHeavy = rainfall > 20.0;
    device.isOnline = isOnline;
    device.lastSeen = DateTime.now();
    _deviceLastReceived[deviceId] = DateTime.now();
    device.lastDataReceived = DateTime.now();

    _checkAndTriggerNotifications();
    _maybeRecordHistorySnapshot(deviceId, device);
    notifyListeners();

    if (_isFirebaseInitialized && _dbRef != null) {
      try {
        _dbRef.child('devices/$deviceId').update({
          'name': device.name,
          'lat': lat,
          'lng': lng,
          'waterLevel': waterLevel,
          'waterFlow': waterFlow,
          'rainfall': rainfall,
        });
      } catch (e) {
        debugPrint('Firebase update error in simulator: $e');
      }
    }
  }

  /// Simulate both Upstream and Downstream stations simultaneously
  void simulateDualStation({
    double? upstreamLevel,
    double? downstreamLevel,
    double? riverbankLevel,
    double? urbanLevel,
    double? rainfall,
    double? flow,
  }) {
    final effectiveUpstream = upstreamLevel ?? riverbankLevel ?? 0.0;
    final effectiveDownstream = downstreamLevel ?? urbanLevel ?? 10.0;

    final up = upstreamDevice;
    if (up != null) {
      simulateDataFromIoT(
        deviceId: up.id,
        lat: up.lat,
        lng: up.lng,
        waterLevel: effectiveUpstream,
        waterFlow: flow ?? 12.0,
        rainfall: rainfall ?? 15.0,
      );
    }
    final down = downstreamDevice;
    if (down != null) {
      simulateDataFromIoT(
        deviceId: down.id,
        lat: down.lat,
        lng: down.lng,
        waterLevel: effectiveDownstream,
        waterFlow: (flow ?? 12.0) * 0.5,
        rainfall: rainfall ?? 15.0,
      );
    }
  }

  /// Simulate a specific station reaching critical flood level to test 20 km proximity alerts
  void simulateStationFlood(
    String deviceId, {
    double waterLevel = 85.0,
    double waterFlow = 25.0,
    double rainfall = 45.0,
  }) {
    if (_devices.containsKey(deviceId)) {
      final dev = _devices[deviceId]!;
      simulateDataFromIoT(
        deviceId: dev.id,
        lat: dev.lat,
        lng: dev.lng,
        waterLevel: waterLevel,
        waterFlow: waterFlow,
        rainfall: rainfall,
      );
    }
  }

  static double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // pi / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * asin... 2 * 6371000 = 12742000 m
  }

  void _checkProximityFloodAlerts() {
    _deviceProximityFloodAlerts.clear();

    // Deduplicate physical stations (ignore legacy alias keys pointing to exact same coordinates)
    final Map<String, DeviceData> uniqueStations = {};
    for (final dev in _devices.values) {
      if (!dev.isDeviceOnline) continue;
      final String coordKey = '${dev.lat.toStringAsFixed(4)},${dev.lng.toStringAsFixed(4)}';
      if (!uniqueStations.containsKey(coordKey)) {
        uniqueStations[coordKey] = dev;
      } else if (dev.waterLevel > uniqueStations[coordKey]!.waterLevel) {
        uniqueStations[coordKey] = dev;
      }
    }

    final activeDevices = uniqueStations.values.toList();
    bool anyFlooding = false;

    for (final source in activeDevices) {
      final bool isFlooding = source.isFloodDanger || source.waterLevel >= source.waterLevelThreshold;
      if (!isFlooding) continue;
      anyFlooding = true;

      for (final target in activeDevices) {
        if (target.id == source.id) continue;
        if (target.lat == source.lat && target.lng == source.lng) continue;

        final double distanceMeters = _calculateDistanceMeters(source.lat, source.lng, target.lat, target.lng);
        final bool isUpstreamDownstreamPair =
            (source.isUpstream && target.isDownstream) || (source.isDownstream && target.isUpstream);

        // Within 20km radius (20,000 meters) or connected network route
        if (distanceMeters <= 20000 || isUpstreamDownstreamPair) {
          final String distanceKm = (distanceMeters / 1000).toStringAsFixed(1);
          final String alertMsg =
              '🚨 แจ้งเตือนภัยวิกฤตในรัศมี 20 กม.! ตรวจพบระดับน้ำวิกฤตที่ "${source.name}" (${source.waterLevel.toStringAsFixed(1)} ซม.) ห่างออกไป $distanceKm กม.! ท่านอยู่ในรัศมีเสี่ยงภัย 20 กม. มีสถานะวิกฤติ โปรดออกห่างจากบริเวณนี้ทันที!';

          _deviceProximityFloodAlerts[target.id] = alertMsg;
          // Also set on alias IDs
          _deviceProximityFloodAlerts['station_upstream'] = alertMsg;
          _deviceProximityFloodAlerts['station_riverbank'] = alertMsg;
          _deviceProximityFloodAlerts['khlong_1'] = alertMsg;
          _deviceProximityFloodAlerts['device_1'] = alertMsg;
          _deviceProximityFloodAlerts['device_test'] = alertMsg;
          _deviceProximityFloodAlerts['station_downstream'] = alertMsg;
          _deviceProximityFloodAlerts['station_urban'] = alertMsg;
          _deviceProximityFloodAlerts['khlong_2'] = alertMsg;

          final String pairKey =
              '${source.id}->${target.id}_${source.waterLevel >= source.waterLevelThreshold ? "danger" : "warn"}';
          if (!_notifiedProximityPairs.contains(pairKey)) {
            _notifiedProximityPairs.add(pairKey);
            final bool isCrit = source.waterLevel >= 60.0 ||
                source.isFloodDanger ||
                source.earlyWarningSeverity == EarlyWarningSeverity.critical;
            final alertTitle = isCrit
                ? '🚨 วิกฤต! อุปกรณ์ในรัศมี 20 กม. เกิดน้ำท่วมสูง'
                : '⚠️ เฝ้าระวัง! อุปกรณ์ในรัศมี 20 กม. ระดับน้ำเพิ่มขึ้น';
            try {
              NotificationService().showEmergencyNotification(
                id: (source.id.hashCode ^ target.id.hashCode).abs() % 100000 + 400,
                title: alertTitle,
                body: alertMsg,
                isCritical: isCrit,
              );
            } catch (_) {}
            _addAlertHistory(
              alertTitle,
              alertMsg,
              'proximity_flood',
            );
          }
        }
      }
    }

    if (!anyFlooding && _notifiedProximityPairs.isNotEmpty) {
      _notifiedProximityPairs.clear();
    }
  }

  void updateWaterLevelThreshold(double threshold) {
    if (currentDevice != null) {
      if (_isFirebaseInitialized && _dbRef != null) {
        _dbRef.child('devices/$_selectedDeviceId').update({'waterLevelThreshold': threshold});
      } else {
        currentDevice!.waterLevelThreshold = threshold;
        notifyListeners();
      }
    }
  }

  void toggleFloodDanger() {
    if (currentDevice != null) {
      simulateDataFromIoT(
        deviceId: _selectedDeviceId,
        lat: currentDevice!.lat,
        lng: currentDevice!.lng,
        waterLevel: currentDevice!.waterLevel < 50 ? 75.0 : 0.0,
        waterFlow: currentDevice!.waterFlow,
        rainfall: currentDevice!.rainfall,
      );
    }
  }

  final Map<String, FloodWarningLevel> _notifiedFloodState = {};
  final Map<String, EarlyWarningSeverity> _notifiedEarlyWarningState = {};
  final Map<String, DateTime> _lastWarningNotificationTime = {};

  void _checkAndTriggerNotifications() {
    _checkProximityFloodAlerts();

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null || user.isAnonymous) {
      return; // Do not trigger local push notifications for guests
    }

    for (var device in _devices.values) {
      if (!device.isDeviceOnline) continue;

      // 1. Proactive Early Warning Notification (Sensors + Weather Forecast Fusion)
      EarlyWarningSeverity lastEarlyWarning = _notifiedEarlyWarningState[device.id] ?? EarlyWarningSeverity.none;
      EarlyWarningSeverity currentEarlyWarning = device.earlyWarningSeverity;

      if (currentEarlyWarning != lastEarlyWarning) {
        if (currentEarlyWarning == EarlyWarningSeverity.critical) {
          _triggerEarlyWarningNotification(device, isCritical: true);
        } else if (currentEarlyWarning == EarlyWarningSeverity.alert && lastEarlyWarning != EarlyWarningSeverity.critical) {
          _triggerEarlyWarningNotification(device, isCritical: false);
        }
        _notifiedEarlyWarningState[device.id] = currentEarlyWarning;
      }

      // 2. Flood Level Threshold Check
      FloodWarningLevel lastFlood = _notifiedFloodState[device.id] ?? FloodWarningLevel.safe;
      FloodWarningLevel currentFlood = device.floodWarningLevel;

      if (currentFlood != lastFlood) {
        if (currentFlood == FloodWarningLevel.emergency) {
          _triggerFloodNotification(device, level: FloodWarningLevel.emergency);
        } else if (currentFlood == FloodWarningLevel.danger) {
          _triggerFloodNotification(device, level: FloodWarningLevel.danger);
        } else if (currentFlood == FloodWarningLevel.warning) {
          _triggerFloodNotification(device, level: FloodWarningLevel.warning);
        }
        _notifiedFloodState[device.id] = currentFlood;
      }
    }
  }

  void _triggerEarlyWarningNotification(DeviceData device, {required bool isCritical}) {
    if (isCritical) {
      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 10,
        title: '🚨 เตือนภัยล่วงหน้าขั้นวิกฤต! (เซนเซอร์+พยากรณ์)',
        body: 'พื้นที่ "${device.name}" คาดการณ์น้ำขึ้นเร็วรวมฝน +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. (โอกาสฝน ${device.forecastRainProb30}%) ${device.compoundTimeToDangerText}',
        isCritical: true,
      );
      _addAlertHistory(
        '🚨 วิกฤตเตือนภัยล่วงหน้า!',
        'รวมน้ำขึ้นเร็ว +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. (ฝน ${device.forecastRainProb30}%) ${device.compoundTimeToDangerText}',
        'early_critical',
      );
    } else {
      // ระดับเฝ้าระวัง: ป้องกันการแจ้งเตือนถี่รบกวนผู้ใช้ (หน่วงเวลา 5 นาที)
      final lastTime = _lastWarningNotificationTime['ew_${device.id}'];
      if (lastTime != null && DateTime.now().difference(lastTime) < const Duration(minutes: 5)) {
        return;
      }
      _lastWarningNotificationTime['ew_${device.id}'] = DateTime.now();

      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 11,
        title: '⚠️ เตือนภัยล่วงหน้า! เสี่ยงน้ำท่วมฉับพลัน',
        body: 'พื้นที่ "${device.name}" ตรวจพบน้ำขึ้นเร็วรวมพยากรณ์ฝน +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. ${device.compoundTimeToDangerText}',
        isCritical: false,
      );
      _addAlertHistory(
        '⚠️ เตือนภัยล่วงหน้า!',
        'อัตราเพิ่มรวมฝน +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. ${device.compoundTimeToDangerText}',
        'early_warning',
      );
    }
  }

  void _triggerFloodNotification(DeviceData device, {FloodWarningLevel? level, bool isDanger = false}) {
    final effectiveLevel = level ?? (isDanger ? (device.waterLevel >= 50.0 ? FloodWarningLevel.emergency : FloodWarningLevel.danger) : FloodWarningLevel.warning);
    if (effectiveLevel == FloodWarningLevel.emergency) {
      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 1,
        title: '🚨 สถานะ : วิกฤตสูงสุด (50 ซม. ขึ้นไป)',
        body: 'พื้นที่ "${device.name}" ระดับน้ำ ${device.waterLevel.toStringAsFixed(1)} ซม. (ไซเรนดังกระหึ่ม! รถเล็กและรถเก๋งเครื่องดับ 100% ห้ามผ่านเด็ดขาด)',
        isCritical: true,
      );
      _addAlertHistory(
        '🚨 สถานะ : วิกฤตสูงสุด',
        'ระดับน้ำแตะ ${device.waterLevel.toStringAsFixed(1)} ซม. (รถเล็กและรถเก๋งเครื่องดับ 100% ห้ามผ่านเด็ดขาด)',
        'emergency',
      );
    } else if (effectiveLevel == FloodWarningLevel.danger) {
      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 2,
        title: '🔴 สถานะ : วิกฤต (30-49.9 ซม.)',
        body: 'พื้นที่ "${device.name}" ระดับน้ำ ${device.waterLevel.toStringAsFixed(1)} ซม. (รถเก๋งเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด)',
        isCritical: true,
      );
      _addAlertHistory(
        '🔴 สถานะ : วิกฤต',
        'ระดับน้ำถึงจุดวิกฤตที่ ${device.waterLevel.toStringAsFixed(1)} ซม. (รถเก๋งเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด)',
        'danger',
      );
    } else {
      // ระดับเฝ้าระวัง: ป้องกันการแจ้งเตือนถี่รบกวนผู้ใช้ (หน่วงเวลา 5 นาที)
      final lastTime = _lastWarningNotificationTime['flood_${device.id}'];
      if (lastTime != null && DateTime.now().difference(lastTime) < const Duration(minutes: 5)) {
        return;
      }
      _lastWarningNotificationTime['flood_${device.id}'] = DateTime.now();

      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 3,
        title: '🟠 สถานะ : เฝ้าระวัง (10-29.9 ซม.)',
        body: 'พื้นที่ "${device.name}" ระดับน้ำ ${device.waterLevel.toStringAsFixed(1)} ซม. (รถเก๋งเริ่มสัญจรลำบาก มอเตอร์ไซค์เสี่ยงเครื่องดับ)',
        isCritical: false,
      );
      _addAlertHistory(
        '🟠 สถานะ : เฝ้าระวัง',
        'ระดับน้ำเฝ้าระวังที่ ${device.waterLevel.toStringAsFixed(1)} ซม. (รถเก๋งเริ่มสัญจรลำบาก)',
        'warning',
      );
    }
  }

  void _addAlertHistory(String title, String subtitle, String type) {
    _alertHistory.insert(0, AlertHistoryItem(
      time: DateTime.now(),
      title: title,
      subtitle: subtitle,
      type: type,
    ));
    if (_alertHistory.length > 50) {
      _alertHistory.removeLast();
    }
    _saveAlertHistory();
    notifyListeners();
  }

  void _parseAndApplyHistory(String deviceId, dynamic data) {
    if (data is! Map) return;

    final List<Map<String, dynamic>> rawData = [];

    data.forEach((key, value) {
      if (value is Map) {
        final int ts = int.tryParse(key.toString().split('_').last) ??
            int.tryParse(key.toString()) ??
            (value['timestamp'] is num ? (value['timestamp'] as num).toInt() : 0);

        final double wl = (value['waterLevel'] is num)
            ? (value['waterLevel'] as num).toDouble()
            : (double.tryParse(value['waterLevel']?.toString() ?? '') ?? 0.0);

        final double rf = (value['rainfall'] is num)
            ? (value['rainfall'] as num).toDouble()
            : (double.tryParse(value['rainfall']?.toString() ?? '') ?? 0.0);

        final double wf = (value['waterFlow'] is num)
            ? (value['waterFlow'] as num).toDouble()
            : (double.tryParse(value['waterFlow']?.toString() ?? '') ?? 0.0);

        final bool isReal = value['isReal'] == true ||
            value['isReal'] == 1 ||
            value['isReal'] == 'true';

        if (ts > 0) {
          rawData.add({
            'timestamp': ts,
            'waterLevel': wl,
            'rainfall': rf,
            'waterFlow': wf,
            'isReal': isReal,
          });
        }
      }
    });

    if (rawData.isNotEmpty) {
      // If real hardware points exist, filter out simulated/seed data
      final hasReal = rawData.any((e) => e['isReal'] == true);
      if (hasReal) {
        rawData.removeWhere((e) => e['isReal'] != true);
      }

      rawData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      final now = DateTime.now().millisecondsSinceEpoch;
      final oneDayMs = 24 * 60 * 60 * 1000;
      final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

      final h24 = rawData.where((e) => now - e['timestamp'] <= oneDayMs).toList();
      List<Map<String, dynamic>> h7d = rawData.where((e) => now - e['timestamp'] <= sevenDaysMs).toList();

      _deviceHistory24h[deviceId] = h24.isNotEmpty ? h24 : rawData;

      if (h7d.length > 30) {
        Map<int, List<Map<String, dynamic>>> dailyGroups = {};
        for (var item in h7d) {
          final day = DateTime.fromMillisecondsSinceEpoch(item['timestamp']).day;
          dailyGroups.putIfAbsent(day, () => []).add(item);
        }
        h7d = dailyGroups.values.map((group) {
          final sumWater = group.fold(0.0, (sum, item) => sum + item['waterLevel']);
          final sumRain = group.fold(0.0, (sum, item) => sum + item['rainfall']);
          final sumFlow = group.fold(0.0, (sum, item) => sum + item['waterFlow']);
          return {
            'timestamp': group.last['timestamp'],
            'waterLevel': sumWater / group.length,
            'rainfall': sumRain / group.length,
            'waterFlow': sumFlow / group.length,
            'isReal': true,
          };
        }).toList();
        h7d.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      }

      _deviceHistory7d[deviceId] = h7d.isNotEmpty ? h7d : rawData;
    }
  }

  Future<void> fetchDeviceHistory(String deviceId, {bool force = false}) async {
    // 24/7 Real-Time History Stream: listen continuously to new snapshots from IoT devices
    if (_dbRef != null && !_historySubscriptions.containsKey(deviceId)) {
      _historySubscriptions[deviceId] = _dbRef
          .child('device_history/$deviceId')
          .limitToLast(168)
          .onValue
          .listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          _parseAndApplyHistory(deviceId, event.snapshot.value);
          notifyListeners();
        }
      }, onError: (e) {
        debugPrint("Error in 24/7 history listener for $deviceId: $e");
      });
    }

    if (!force && _historyFetchedDeviceIds.contains(deviceId)) {
      return;
    }
    _historyFetchedDeviceIds.add(deviceId);

    // Only set loading if we don't have memory-cached data yet
    final bool hasData = _deviceHistory24h[deviceId]?.isNotEmpty ?? false;
    if (!hasData) {
      _isLoadingHistory = true;
      notifyListeners();
    }

    if (_dbRef == null) {
      if (_isLoadingHistory) {
        _isLoadingHistory = false;
        notifyListeners();
      }
      return;
    }

    try {
      final historyRef = _dbRef.child('device_history/$deviceId');
      final snapshot = await historyRef.orderByKey().limitToLast(168).get().timeout(const Duration(seconds: 4));

      if (!snapshot.exists || snapshot.value == null) {
        await _seedDeviceHistoryIfNeeded(deviceId);
        return;
      }

      _parseAndApplyHistory(deviceId, snapshot.value);
    } catch (e) {
      debugPrint("Error fetching history for $deviceId: $e");
    } finally {
      if (_isLoadingHistory) {
        _isLoadingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> _maybeRecordHistorySnapshot(String deviceId, DeviceData device) async {
    if (!device.isDeviceOnline) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int? lastTime = _lastSnapshotTimeMs[deviceId];
    final double? lastLevel = _lastSnapshotWaterLevel[deviceId];

    bool shouldRecord = false;
    if (lastTime == null) {
      // Record initial point when device is first detected online
      shouldRecord = true;
    } else {
      final int diffSeconds = (nowMs - lastTime) ~/ 1000;
      // 24/7 continuous logging every 3 minutes (180 seconds)
      if (diffSeconds >= 180) {
        shouldRecord = true;
      }
      // Record when water level changes significantly (>= 1.0 cm) and >= 20 seconds have passed
      else if (lastLevel != null && (device.waterLevel - lastLevel).abs() >= 1.0 && diffSeconds >= 20) {
        shouldRecord = true;
      }
    }

    if (shouldRecord) {
      _lastSnapshotTimeMs[deviceId] = nowMs;
      _lastSnapshotWaterLevel[deviceId] = device.waterLevel;
      await recordDeviceSnapshot(
        deviceId,
        device.waterLevel,
        rainfall: device.rainfall,
        waterFlow: device.waterFlow,
      );
    }
  }

  Future<void> recordDeviceSnapshot(
    String deviceId,
    double waterLevel, {
    double rainfall = 0.0,
    double waterFlow = 0.0,
  }) async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final snapshotData = {
      'timestamp': nowMs,
      'waterLevel': double.parse(waterLevel.toStringAsFixed(1)),
      'rainfall': double.parse(rainfall.toStringAsFixed(1)),
      'waterFlow': double.parse(waterFlow.toStringAsFixed(1)),
      'isReal': true,
    };

    // If local history currently contains only simulated items, replace with real
    if (_deviceHistory24h.containsKey(deviceId)) {
      final hasReal = _deviceHistory24h[deviceId]!.any((e) => e['isReal'] == true);
      if (!hasReal) {
        _deviceHistory24h[deviceId] = [];
      }
    }
    if (_deviceHistory7d.containsKey(deviceId)) {
      final hasReal = _deviceHistory7d[deviceId]!.any((e) => e['isReal'] == true);
      if (!hasReal) {
        _deviceHistory7d[deviceId] = [];
      }
    }

    _deviceHistory24h.putIfAbsent(deviceId, () => []);
    _deviceHistory7d.putIfAbsent(deviceId, () => []);

    _deviceHistory24h[deviceId]!.add(snapshotData);
    _deviceHistory7d[deviceId]!.add(snapshotData);

    if (_deviceHistory24h[deviceId]!.length > 168) {
      _deviceHistory24h[deviceId]!.removeAt(0);
    }
    if (_deviceHistory7d[deviceId]!.length > 500) {
      _deviceHistory7d[deviceId]!.removeAt(0);
    }

    notifyListeners();

    if (_dbRef != null) {
      try {
        final historyRef = _dbRef.child('device_history/$deviceId/timestamp_$nowMs');
        await historyRef.set(snapshotData);
      } catch (e) {
        debugPrint("Error writing history snapshot to Firebase: $e");
      }
    }
  }

  Future<void> recordCurrentSnapshot({String? deviceId}) async {
    final id = deviceId ?? _selectedDeviceId;
    final dev = _devices[id];
    if (dev != null) {
      _lastSnapshotTimeMs[id] = DateTime.now().millisecondsSinceEpoch;
      _lastSnapshotWaterLevel[id] = dev.waterLevel;
      await recordDeviceSnapshot(id, dev.waterLevel, rainfall: dev.rainfall, waterFlow: dev.waterFlow);
    }
  }

  Future<void> clearSimulatedHistory(String deviceId) async {
    if (_dbRef != null) {
      try {
        final historyRef = _dbRef.child('device_history/$deviceId');
        final snapshot = await historyRef.get();
        if (snapshot.exists && snapshot.value is Map) {
          final data = snapshot.value as Map;
          for (var entry in data.entries) {
            if (entry.value is Map && entry.value['isReal'] != true) {
              await historyRef.child(entry.key.toString()).remove();
            }
          }
        }
      } catch (e) {
        debugPrint("Error clearing simulated history: $e");
      }
    }
    _deviceHistory24h[deviceId] = [];
    _deviceHistory7d[deviceId] = [];
    await fetchDeviceHistory(deviceId, force: true);
    notifyListeners();
  }

  Future<void> _seedDeviceHistoryIfNeeded(String deviceId) async {
    final fallback24 = _generateFallbackHistory(deviceId, hours: 24);
    final fallback7d = _generateFallbackHistory(deviceId, hours: 168);

    _deviceHistory24h[deviceId] = fallback24;
    _deviceHistory7d[deviceId] = fallback7d;

    if (_dbRef != null) {
      try {
        final historyRef = _dbRef.child('device_history/$deviceId');
        Map<String, dynamic> seedData = {};
        for (var item in fallback7d) {
          seedData['timestamp_${item['timestamp']}'] = {
            'waterLevel': item['waterLevel'],
            'rainfall': item['rainfall'],
            'waterFlow': item['waterFlow'],
          };
        }
        await historyRef.set(seedData).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("Firebase seed skipped or not permitted: $e");
      }
    }
  }
}
