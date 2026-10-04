import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

enum FloodWarningLevel { safe, warning, danger }

enum EarlyWarningSeverity { none, advisory, alert, critical }

class DeviceData {
  final String id;
  String name;
  double lat;
  double lng;
  double waterLevel;
  double waterFlow;
  bool isElectricalLeakage;
  double rainfall;
  String weatherStatus;
  double waterLevelThreshold;
  double leakageProbability;
  
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
  bool hasCurrentSensor;
  bool hasWaterLevelSensor;

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
    this.waterLevel = 15.0,
    this.waterFlow = 5.0,
    this.isElectricalLeakage = false,
    this.rainfall = 5.0,
    this.weatherStatus = 'ปกติ',
    this.waterLevelThreshold = 50.0,
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
    this.hasCurrentSensor = false,
    this.hasWaterLevelSensor = true,
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
        _modules = modules ?? const {},
        leakageProbability = isElectricalLeakage ? 0.85 : 0.05;

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
      'currentSensor': {
        'name': 'เซนเซอร์วัดกระแสไฟฟ้ารั่ว (Current Sensor)',
        'model': 'รุ่น SCT-013 Non-Invasive AC Current',
        'installed': hasCurrentSensor,
        'status': hasCurrentSensor ? (isElectricalLeakage ? 'WARNING' : 'OK') : 'NOT_INSTALLED',
        'message': hasCurrentSensor
            ? (isElectricalLeakage ? '⚠️ ตรวจพบกระแสไฟฟ้ารั่วไหล!' : 'ปกติ • กระแสไฟ 0.00A (ปลอดภัย)')
            : 'ยังไม่ได้ติดตั้งเซนเซอร์วัดกระแสไฟ',
        'icon': 'bolt',
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
    if (waterLevel >= 60) return FloodWarningLevel.danger;
    if (waterLevel >= 20) return FloodWarningLevel.warning;
    
    // Proactive Early Warning triggers escalation
    if (earlyWarningSeverity == EarlyWarningSeverity.critical ||
        earlyWarningSeverity == EarlyWarningSeverity.alert) {
      return FloodWarningLevel.warning;
    }
    if (risingSpeed > 10.0 || isRainingHeavy || rainfall >= 30) {
      return FloodWarningLevel.warning;
    }
    
    return FloodWarningLevel.safe;
  }

  bool get isFloodDanger => floodWarningLevel == FloodWarningLevel.danger;
  bool get isFloodWarning => floodWarningLevel == FloodWarningLevel.warning;

  String get systemStatus {
    if (isElectricalLeakage) return 'อันตรายไฟฟ้ารั่ว';
    if (isFloodDanger) return 'อันตรายน้ำท่วม';
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
    return 'ปลอดภัย';
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
  String _selectedDeviceId = 'khlong_1';

  final DatabaseReference _dbRef;
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

  void updateRainfallFromWeatherApi({
    required double precipitation,
    required String description,
    required int prob30,
    int? prob60,
    int? prob90,
  }) {
    bool updated = false;
    for (final device in _devices.values) {
      final double effectiveRainfall = precipitation > 0 ? precipitation : (prob30 >= 60 ? 15.0 : 0.0);
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
  bool _hasManuallySelectedDevice = false;
  final Map<String, int> _lastSnapshotTimeMs = {};
  final Map<String, double> _lastSnapshotWaterLevel = {};

  SensorProvider() : _dbRef = FirebaseDatabase.instance.ref() {
    _loadAlertHistory();
    _initMockDevices();
    _initFirebaseListener();
    _initSosListener();
    _startHistoryTimer();
    _startHeartbeatTimer();
    _startAutoLogTimer();
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
  }) async {
    final now = DateTime.now();
    final newRef = _dbRef.child('sos_requests').push();
    final id = newRef.key ?? now.millisecondsSinceEpoch.toString();
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
    );

    // Optimistic local update so it shows immediately
    _sosRequests.removeWhere((s) => s.id == item.id);
    _sosRequests.insert(0, item);
    notifyListeners();

    try {
      await newRef.set(item.toJson());
      // Dual-write to admin_reports so it shows in the Reports tab as well
      final reportRef = _dbRef.child('admin_reports').push();
      await reportRef.set({
        'title': '🚨 ขอความช่วยเหลือฉุกเฉิน (SOS): $userName',
        'description': 'สถานการณ์: $situation\nเบอร์ติดต่อ: $phoneNumber\nรายละเอียด: ${note.isNotEmpty ? note : "-"}\nพิกัด: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        'type': 'sos',
        'lat': lat,
        'lng': lng,
        'status': 'pending',
        'timestamp': now.millisecondsSinceEpoch,
        'sosId': id,
        'reporterName': userName,
        'reporterPhone': phoneNumber,
      });
    } catch (e) {
      debugPrint("Error sending SOS request to Firebase: $e");
    }
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
      );
      notifyListeners();
    }
    try {
      await _dbRef.child('sos_requests/$sosId/status').set(newStatus);
    } catch (e) {
      debugPrint("Error updating SOS status in Firebase: $e");
    }
  }

  Future<void> updateDeviceCalibration(String deviceId, double sensorHeight) async {
    if (_devices.containsKey(deviceId)) {
      _devices[deviceId]!.sensorHeight = sensorHeight;
    }
    await _dbRef.child('devices/$deviceId/sensorHeight').set(sensorHeight);
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
ระบบเตือนภัยน้ำท่วมและเฝ้าระวังไฟฟ้ารั่ว GIS
==========================================
📅 วันที่ออกรายงาน: $dateStr
📍 สถานี: ${device.name} (รหัส: ${device.id})
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

⚡ การตรวจจับกระแสไฟฟ้ารั่ว:
- สถานะไฟฟ้ารั่ว: ${device.isElectricalLeakage ? '⚠️ ตรวจพบไฟฟ้ารั่วไหลในน้ำ (อันตราย!)' : 'ปกติ (ไม่พบไฟฟ้ารั่ว)'}

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

  void _startHistoryTimer() {
    _historyTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_devices.isNotEmpty) {
        _devices.forEach((id, device) {
          _deviceWaterLevelHistory.putIfAbsent(id, () => List.filled(21, device.waterLevel, growable: true));
          _deviceRainfallHistory.putIfAbsent(id, () => List.filled(21, device.rainfall, growable: true));
          _deviceWaterFlowHistory.putIfAbsent(id, () => List.filled(21, device.waterFlow, growable: true));

          final wlList = _deviceWaterLevelHistory[id]!;
          final rfList = _deviceRainfallHistory[id]!;
          final wfList = _deviceWaterFlowHistory[id]!;

          wlList.add(device.waterLevel);
          rfList.add(device.rainfall);
          wfList.add(device.waterFlow);

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
      waterLevel: 15.0,
      waterFlow: 5.0,
      isElectricalLeakage: false,
      rainfall: 0.0,
    );
    _devices[id] = newDevice;
    _deviceWaterLevelHistory[id] = List.filled(21, 15.0, growable: true);
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
    for (var sub in _historySubscriptions.values) {
      sub.cancel();
    }
    _historySubscriptions.clear();
    super.dispose();
  }

  List<double> get waterLevelHistory {
    if (_deviceWaterLevelHistory.containsKey(_selectedDeviceId)) {
      return _deviceWaterLevelHistory[_selectedDeviceId]!;
    }
    return List.filled(21, currentDevice?.waterLevel ?? 15.0, growable: true);
  }

  List<double> get rainfallHistory {
    if (_deviceRainfallHistory.containsKey(_selectedDeviceId)) {
      return _deviceRainfallHistory[_selectedDeviceId]!;
    }
    return List.filled(21, currentDevice?.rainfall ?? 5.0, growable: true);
  }

  List<double> get waterFlowHistory {
    if (_deviceWaterFlowHistory.containsKey(_selectedDeviceId)) {
      return _deviceWaterFlowHistory[_selectedDeviceId]!;
    }
    return List.filled(21, currentDevice?.waterFlow ?? 5.0, growable: true);
  }

  void _initMockDevices() {
    _devices = {
      'khlong_1': DeviceData(
        id: 'khlong_1',
        name: 'คลอง 1',
        lat: 13.7563,
        lng: 100.5018,
        waterLevel: 25.0,
        waterFlow: 8.0,
        batteryPercent: 92,
        batteryVoltage: 4.1,
        sensorHeight: 200.0,
        signalPercent: 88,
        signalRssi: -58,
        networkType: 'Wi-Fi (2.4 GHz)',
        wifiSsid: 'WaterMonitor_2.4G',
        ipAddress: '192.168.1.104',
        hasWifiData: true,
      ),
      'khlong_2': DeviceData(
        id: 'khlong_2',
        name: 'คลอง 2',
        lat: 13.7600,
        lng: 100.5100,
        waterLevel: 58.0,
        waterFlow: 18.0,
        batteryPercent: 78,
        batteryVoltage: 3.8,
        sensorHeight: 250.0,
        signalPercent: 65,
        signalRssi: -68,
        networkType: 'Wi-Fi (2.4 GHz)',
        wifiSsid: 'FloodAlert_AP',
        ipAddress: '192.168.1.108',
        hasWifiData: true,
      ),
    };
    _selectedDeviceId = 'khlong_1';
    _deviceHistory24h['khlong_1'] = _generateFallbackHistory('khlong_1', hours: 24);
    _deviceHistory7d['khlong_1'] = _generateFallbackHistory('khlong_1', hours: 168);
    _deviceHistory24h['khlong_2'] = _generateFallbackHistory('khlong_2', hours: 24);
    _deviceHistory7d['khlong_2'] = _generateFallbackHistory('khlong_2', hours: 168);
  }

  void _initFirebaseListener() {
    try {
      _dbRef.child('devices').onValue.listen((event) {
        if (!event.snapshot.exists) {
          _initMockDevices();
          notifyListeners();
        } else {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final Map<String, DeviceData> newDevices = {};
          data.forEach((key, value) {
            if (value is! Map) return;
            final String id = key.toString();
            final Map<dynamic, dynamic> deviceData = value;
            
            // Safe type parsing for Firebase fields
            final double currentWaterLevel = (deviceData['waterLevel'] is num)
                ? (deviceData['waterLevel'] as num).toDouble()
                : (double.tryParse(deviceData['waterLevel']?.toString() ?? '') ?? 15.0);

            final double currentWaterFlow = (deviceData['waterFlow'] is num)
                ? (deviceData['waterFlow'] as num).toDouble()
                : (double.tryParse(deviceData['waterFlow']?.toString() ?? '') ?? 5.0);

            final double currentRainfall = (deviceData['rainfall'] is num)
                ? (deviceData['rainfall'] as num).toDouble()
                : (double.tryParse(deviceData['rainfall']?.toString() ?? '') ?? 0.0);

            bool isLeakage = false;
            final rawLeakage = deviceData['isElectricalLeakage'];
            if (rawLeakage is bool) {
              isLeakage = rawLeakage;
            } else if (rawLeakage is num) {
              isLeakage = rawLeakage != 0;
            } else if (rawLeakage is String) {
              isLeakage = rawLeakage.toLowerCase() == 'true' || rawLeakage == '1';
            }

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

            // Calculate Rate of Change (RoC)
            double calculatedRisingSpeed = 0.0;
            if (_devices.containsKey(id)) {
              final previousWaterLevel = _devices[id]!.waterLevel;
              final double difference = currentWaterLevel - previousWaterLevel;
              if (difference > 0) {
                calculatedRisingSpeed = difference * (60.0 / 5.0);
              } else if (difference == 0) {
                calculatedRisingSpeed = _devices[id]!.risingSpeed * 0.5;
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

            bool hasCurrent = false;
            final rawHasCurrent = deviceData['hasCurrentSensor'] ??
                deviceData['isCurrentSensorInstalled'] ??
                deviceData['currentSensorInstalled'];
            if (rawHasCurrent is bool) {
              hasCurrent = rawHasCurrent;
            } else if (rawHasCurrent is num) {
              hasCurrent = rawHasCurrent != 0;
            } else if (rawHasCurrent is String) {
              hasCurrent = rawHasCurrent.toLowerCase() == 'true' || rawHasCurrent == '1';
            } else if (deviceData['modules'] is Map && (deviceData['modules'] as Map).containsKey('currentSensor')) {
              final cMod = (deviceData['modules'] as Map)['currentSensor'];
              if (cMod is Map) {
                hasCurrent = cMod['installed'] == true;
              }
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

            newDevices[id] = DeviceData(
              id: id,
              name: deviceData['name']?.toString() ?? 'Device $id',
              lat: (deviceData['lat'] is num) ? (deviceData['lat'] as num).toDouble() : (double.tryParse(deviceData['lat']?.toString() ?? '') ?? 13.7563),
              lng: (deviceData['lng'] is num) ? (deviceData['lng'] as num).toDouble() : (double.tryParse(deviceData['lng']?.toString() ?? '') ?? 100.5018),
              waterLevel: currentWaterLevel,
              waterFlow: currentWaterFlow,
              isElectricalLeakage: isLeakage,
              rainfall: currentRainfall,
              weatherStatus: deviceData['weatherStatus']?.toString() ?? 'ปกติ',
              waterLevelThreshold: (deviceData['waterLevelThreshold'] is num) ? (deviceData['waterLevelThreshold'] as num).toDouble() : 50.0,
              risingSpeed: calculatedRisingSpeed,
              isRainingHeavy: rainingHeavy,
              forecastRainProb30: fProb30,
              forecastRainProb60: fProb60,
              forecastRainProb90: fProb90,
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
              hasCurrentSensor: hasCurrent,
              hasWaterLevelSensor: hasWater,
              lastSeen: lastSeen,
              lastDataReceived: _deviceLastReceived[id],
              boardModel: deviceData['boardModel']?.toString() ?? 'ESP32-WROOM-32',
              firmware: deviceData['firmware']?.toString() ?? 'v2.0-auto',
              modules: modules,
            );
          });
          _devices.clear();
          _devices.addAll(newDevices);
        }
          // Smart Station Selection:
          // 1. If currently selected device is not in list, auto-select the online sensor
          if (!_devices.containsKey(_selectedDeviceId)) {
            final activeDev = _devices.values.firstWhere(
              (d) => d.isDeviceOnline,
              orElse: () => _devices.values.first,
            );
            _selectedDeviceId = activeDev.id;
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
      await _dbRef.child('devices/$deviceId/isOnline').set(online);
      if (_devices.containsKey(deviceId)) {
        _devices[deviceId]!.isOnline = online;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error setting device online status: $e');
    }
  }

  Future<void> toggleCurrentSensorInstalled(String deviceId, bool installed) async {
    try {
      await _dbRef.child('devices/$deviceId/hasCurrentSensor').set(installed);
      if (_devices.containsKey(deviceId)) {
        _devices[deviceId]!.hasCurrentSensor = installed;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling current sensor: $e');
    }
  }

  Future<void> toggleWaterLevelSensorInstalled(String deviceId, bool installed) async {
    try {
      await _dbRef.child('devices/$deviceId/hasWaterLevelSensor').set(installed);
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
  
  DeviceData? get currentDevice => _devices[_selectedDeviceId];

  // Shorthands for backward compatibility / easy access in views
  double get waterLevel => currentDevice?.waterLevel ?? 0.0;
  double get waterFlow => currentDevice?.waterFlow ?? 0.0;
  String get waterFlowStatus => currentDevice?.waterFlowStatus ?? 'นิ่ง';
  bool get isElectricalLeakage => currentDevice?.isElectricalLeakage ?? false;
  double get leakageProbability => currentDevice?.leakageProbability ?? 0.0;
  String get weatherStatus => currentDevice?.weatherStatus ?? 'ปกติ';
  double get rainfall => currentDevice?.rainfall ?? 0.0;
  double get waterLevelThreshold => currentDevice?.waterLevelThreshold ?? 50.0;
  double get risingSpeed => currentDevice?.risingSpeed ?? 0.0;
  bool get isRainingHeavy => currentDevice?.isRainingHeavy ?? false;
  bool get isFloodDanger => currentDevice?.isFloodDanger ?? false;
  bool get isFloodWarning => currentDevice?.isFloodWarning ?? false;
  bool get isEarlyWarning => currentDevice?.isEarlyWarning ?? false;
  double get compoundRisingSpeed => currentDevice?.compoundRisingSpeed ?? 0.0;
  EarlyWarningSeverity get earlyWarningSeverity => currentDevice?.earlyWarningSeverity ?? EarlyWarningSeverity.none;
  String get smartEarlyWarningTitle => currentDevice?.smartEarlyWarningTitle ?? 'สภาวะระดับน้ำปกติ';
  String get smartEarlyWarningBannerText => currentDevice?.smartEarlyWarningBannerText ?? '';
  String get compoundTimeToDangerText => currentDevice?.compoundTimeToDangerText ?? '';
  int get forecastRainProb30 => currentDevice?.forecastRainProb30 ?? 20;
  int get forecastRainProb60 => currentDevice?.forecastRainProb60 ?? 30;
  int get forecastRainProb90 => currentDevice?.forecastRainProb90 ?? 15;
  FloodWarningLevel get floodWarningLevel => currentDevice?.floodWarningLevel ?? FloodWarningLevel.safe;
  String get systemStatus => currentDevice?.systemStatus ?? 'รอข้อมูล...';
  bool get isDeviceOnline => currentDevice?.isDeviceOnline ?? true;

  void selectDevice(String deviceId) {
    if (_devices.containsKey(deviceId)) {
      _selectedDeviceId = deviceId;
      _hasManuallySelectedDevice = true;
      if (!_historyFetchedDeviceIds.contains(deviceId)) {
        fetchDeviceHistory(deviceId);
      }
      notifyListeners();
    }
  }

  // Used by Simulator Screen
  void simulateDataFromIoT({
    required String deviceId,
    required double lat,
    required double lng,
    required double waterLevel,
    required double waterFlow,
    required bool isLeakage,
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
    device.isElectricalLeakage = isLeakage;
    device.rainfall = rainfall;
    device.isRainingHeavy = rainfall > 20.0;
    device.leakageProbability = isLeakage ? 0.85 : 0.05;
    device.isOnline = isOnline;
    device.lastSeen = DateTime.now();
    _deviceLastReceived[deviceId] = DateTime.now();
    device.lastDataReceived = DateTime.now();

    _checkAndTriggerNotifications();
    _maybeRecordHistorySnapshot(deviceId, device);
    notifyListeners();

    if (_isFirebaseInitialized) {
      try {
        _dbRef.child('devices/$deviceId').update({
          'name': device.name,
          'lat': lat,
          'lng': lng,
          'waterLevel': waterLevel,
          'waterFlow': waterFlow,
          'isElectricalLeakage': isLeakage,
          'rainfall': rainfall,
        });
      } catch (e) {
        debugPrint('Firebase update error in simulator: $e');
      }
    }
  }

  void updateWaterLevelThreshold(double threshold) {
    if (currentDevice != null) {
      if (_isFirebaseInitialized) {
        _dbRef.child('devices/$_selectedDeviceId').update({'waterLevelThreshold': threshold});
      } else {
        currentDevice!.waterLevelThreshold = threshold;
        notifyListeners();
      }
    }
  }

  // Helper method to toggle danger states for testing (Dashboard buttons)
  void toggleLeakageDanger() {
    if (currentDevice != null) {
      simulateDataFromIoT(
        deviceId: _selectedDeviceId,
        lat: currentDevice!.lat,
        lng: currentDevice!.lng,
        waterLevel: currentDevice!.waterLevel,
        waterFlow: currentDevice!.waterFlow,
        isLeakage: !currentDevice!.isElectricalLeakage,
        rainfall: currentDevice!.rainfall,
      );
    }
  }

  void toggleFloodDanger() {
    if (currentDevice != null) {
      simulateDataFromIoT(
        deviceId: _selectedDeviceId,
        lat: currentDevice!.lat,
        lng: currentDevice!.lng,
        waterLevel: currentDevice!.waterLevel < 50 ? 75.0 : 15.0,
        waterFlow: currentDevice!.waterFlow,
        isLeakage: currentDevice!.isElectricalLeakage,
        rainfall: currentDevice!.rainfall,
      );
    }
  }

  final Map<String, FloodWarningLevel> _notifiedFloodState = {};
  final Map<String, bool> _notifiedLeakageState = {};
  final Map<String, EarlyWarningSeverity> _notifiedEarlyWarningState = {};

  void _checkAndTriggerNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return; // Do not trigger local push notifications for guests
    }

    for (var device in _devices.values) {
      // 1. Electrical Leakage Check
      bool lastLeakage = _notifiedLeakageState[device.id] ?? false;
      if (device.isElectricalLeakage && !lastLeakage) {
        _triggerLeakageNotification(device);
        _notifiedLeakageState[device.id] = true;
      } else if (!device.isElectricalLeakage) {
        _notifiedLeakageState[device.id] = false;
      }

      // 2. Proactive Early Warning Notification (Sensors + Weather Forecast Fusion)
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

      // 3. Flood Level Threshold Check
      FloodWarningLevel lastFlood = _notifiedFloodState[device.id] ?? FloodWarningLevel.safe;
      FloodWarningLevel currentFlood = device.floodWarningLevel;

      if (currentFlood != lastFlood) {
        if (currentFlood == FloodWarningLevel.danger) {
          _triggerFloodNotification(device, isDanger: true);
        } else if (currentFlood == FloodWarningLevel.warning) {
          _triggerFloodNotification(device, isDanger: false);
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
      );
      _addAlertHistory(
        '🚨 วิกฤตเตือนภัยล่วงหน้า!',
        'รวมน้ำขึ้นเร็ว +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. (ฝน ${device.forecastRainProb30}%) ${device.compoundTimeToDangerText}',
        'early_critical',
      );
    } else {
      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 11,
        title: '⚠️ เตือนภัยล่วงหน้า! เสี่ยงน้ำท่วมฉับพลัน',
        body: 'พื้นที่ "${device.name}" ตรวจพบน้ำขึ้นเร็วรวมพยากรณ์ฝน +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. ${device.compoundTimeToDangerText}',
      );
      _addAlertHistory(
        '⚠️ เตือนภัยล่วงหน้า!',
        'อัตราเพิ่มรวมฝน +${device.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. ${device.compoundTimeToDangerText}',
        'early_warning',
      );
    }
  }

  void _triggerLeakageNotification(DeviceData device) {
    NotificationService().showEmergencyNotification(
      id: device.id.hashCode + 1,
      title: '🚨 อันตราย! ไฟฟ้ารั่วไหล',
      body: 'ตรวจพบกระแสไฟฟ้ารั่วที่ "${device.name}" โปรดระมัดระวัง',
    );
    _addAlertHistory('🚨 อันตราย! ไฟฟ้ารั่วไหล', 'ตรวจพบกระแสไฟฟ้ารั่วที่ "${device.name}"', 'leakage');
  }

  void _triggerFloodNotification(DeviceData device, {required bool isDanger}) {
    if (isDanger) {
      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 2,
        title: '⚠️ วิกฤต! น้ำท่วมสูง',
        body: 'ระดับน้ำที่ "${device.name}" ถึงจุดวิกฤต (${device.waterLevel.toStringAsFixed(1)} cm)',
      );
      _addAlertHistory('⚠️ วิกฤต! น้ำท่วมสูง', 'ระดับน้ำถึงจุดวิกฤตที่ ${device.waterLevel.toStringAsFixed(1)} cm', 'danger');
    } else {
      NotificationService().showEmergencyNotification(
        id: device.id.hashCode + 3,
        title: '⚠️ เฝ้าระวัง! ระดับน้ำเพิ่มขึ้น',
        body: 'ระดับน้ำที่ "${device.name}" อยู่ในเกณฑ์เฝ้าระวัง (${device.waterLevel.toStringAsFixed(1)} cm)',
      );
      _addAlertHistory('⚠️ เฝ้าระวัง! ระดับน้ำเพิ่มขึ้น', 'ระดับน้ำเฝ้าระวังที่ ${device.waterLevel.toStringAsFixed(1)} cm', 'warning');
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
    if (!_historySubscriptions.containsKey(deviceId)) {
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

    try {
      final historyRef = _dbRef.child('device_history/$deviceId/timestamp_$nowMs');
      await historyRef.set(snapshotData);
    } catch (e) {
      debugPrint("Error writing history snapshot to Firebase: $e");
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
      _deviceHistory24h[deviceId] = [];
      _deviceHistory7d[deviceId] = [];
      await fetchDeviceHistory(deviceId, force: true);
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing simulated history: $e");
    }
  }

  Future<void> _seedDeviceHistoryIfNeeded(String deviceId) async {
    final fallback24 = _generateFallbackHistory(deviceId, hours: 24);
    final fallback7d = _generateFallbackHistory(deviceId, hours: 168);

    _deviceHistory24h[deviceId] = fallback24;
    _deviceHistory7d[deviceId] = fallback7d;

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
