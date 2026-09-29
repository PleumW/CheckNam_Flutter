import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

enum FloodWarningLevel { safe, warning, danger }

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
  
  // Early Warning Features (RoC and Virtual Sensor)
  double risingSpeed; // cm per hour
  bool isRainingHeavy;

  // IoT Internet & Signal Telemetry
  int signalPercent;
  int signalRssi;
  String networkType;
  int pingMs;

  // Hardware Health & Energy Telemetry
  int batteryPercent;
  double batteryVoltage;
  double sensorHeight; // cm from sensor head to bed/ground

  // Sensor Online / Offline Telemetry
  bool isOnline;
  DateTime? lastSeen;

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
    this.signalPercent = 88,
    this.signalRssi = -62,
    this.networkType = '4G LTE / Wi-Fi',
    this.pingMs = 24,
    this.batteryPercent = 85,
    this.batteryVoltage = 3.9,
    this.sensorHeight = 200.0,
    this.isOnline = true,
    this.lastSeen,
    String? boardModel,
    String? firmware,
    Map<String, dynamic>? modules,
  })  : _boardModel = boardModel ?? 'ESP32-WROOM-32',
        _firmware = firmware ?? 'v2.0-auto',
        _modules = modules ?? const {},
        leakageProbability = isElectricalLeakage ? 0.85 : 0.05;

  Map<String, dynamic> get dynamicModules {
    if (modules.isNotEmpty) return modules;
    final bool ultrasonicOk = waterLevel >= 0 && waterLevel <= 300;
    return {
      'ultrasonic': {
        'name': 'เซนเซอร์วัดระดับน้ำ (Ultrasonic Sensor)',
        'model': 'รุ่น JSN-SR04T Waterproof Ultrasonic',
        'installed': true,
        'status': ultrasonicOk ? 'OK' : 'FAULT',
        'message': ultrasonicOk ? 'ปกติ • วัดได้ ${waterLevel.toStringAsFixed(1)} ซม.' : 'เซนเซอร์ชำรุด / อ่านค่าไม่ได้!',
        'icon': 'water_drop',
      },
      'currentSensor': {
        'name': 'เซนเซอร์วัดกระแสไฟฟ้ารั่ว (Current Sensor)',
        'model': 'รุ่น SCT-013 Non-Invasive AC Current',
        'installed': true,
        'status': isElectricalLeakage ? 'WARNING' : 'OK',
        'message': isElectricalLeakage ? '⚠️ ตรวจพบกระแสไฟฟ้ารั่วไหล!' : 'ปกติ • กระแสไฟ 0.00A (ปลอดภัย)',
        'icon': 'bolt',
      },
    };
  }

  bool get isDeviceOnline {
    if (!isOnline) return false;
    if (signalPercent <= 0) return false;
    if (lastSeen != null && DateTime.now().difference(lastSeen!).inMinutes >= 10) {
      return false;
    }
    return true;
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
    final b = signalBars;
    if (b == 4) return '4/4 ขีด (สัญญาณเต็ม)';
    if (b == 3) return '3/4 ขีด (ดีมาก)';
    if (b == 2) return '2/4 ขีด (ปานกลาง)';
    if (b == 1) return '1/4 ขีด (อ่อน)';
    return '0/4 ขีด (ไม่มีสัญญาณ)';
  }

  String get signalQualityText {
    if (signalPercent >= 80) return 'ดีมาก (สัญญาณเสถียรสูง)';
    if (signalPercent >= 50) return 'ปานกลาง (ใช้งานได้ดี)';
    if (signalPercent >= 25) return 'สัญญาณอ่อน';
    return 'สัญญาณอ่อนมาก (อาจขาดการติดต่อ)';
  }

  Color get signalColor {
    if (signalPercent >= 80) return Colors.green;
    if (signalPercent >= 50) return Colors.blueAccent;
    if (signalPercent >= 25) return Colors.orange;
    return Colors.redAccent;
  }

  IconData get signalIcon {
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

  FloodWarningLevel get floodWarningLevel {
    if (waterLevel >= 60) return FloodWarningLevel.danger;
    if (waterLevel >= 20) return FloodWarningLevel.warning;
    
    // Early Warning triggers
    if (risingSpeed > 10.0 || isRainingHeavy) return FloodWarningLevel.warning;
    if (rainfall >= 30) return FloodWarningLevel.warning;
    
    return FloodWarningLevel.safe;
  }

  bool get isFloodDanger => floodWarningLevel == FloodWarningLevel.danger;
  bool get isFloodWarning => floodWarningLevel == FloodWarningLevel.warning;
  bool get isEarlyWarning => (risingSpeed > 10.0 || isRainingHeavy) && waterLevel < 20;

  String get systemStatus {
    if (isElectricalLeakage) return 'อันตรายไฟฟ้ารั่ว';
    if (isFloodDanger) return 'อันตรายน้ำท่วม';
    if (isEarlyWarning && isRainingHeavy && risingSpeed > 10) return 'เตือนภัยล่วงหน้า! น้ำขึ้นเร็ว+ฝนตก';
    if (isEarlyWarning && risingSpeed > 10) return 'เตือนภัยล่วงหน้า! น้ำขึ้นเร็ว';
    if (isEarlyWarning && isRainingHeavy) return 'เตือนภัยล่วงหน้า! พายุเข้า';
    if (isFloodWarning) return 'เฝ้าระวังน้ำท่วม';
    return 'ปลอดภัย';
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
    if (risingSpeed > 15.0) return 'ระดับน้ำกำลังเพิ่มขึ้นอย่างรวดเร็ว (เสี่ยงสูง)';
    if (risingSpeed > 3.0) return 'ระดับน้ำมีแนวโน้มเพิ่มขึ้น';
    if (risingSpeed < -3.0) return 'ระดับน้ำกำลังลดลง';
    return 'ระดับน้ำทรงตัว (ปลอดภัย)';
  }

  Color get trendColor {
    if (risingSpeed > 15.0) return const Color(0xFFEF4444);
    if (risingSpeed > 3.0) return const Color(0xFFF59E0B);
    if (risingSpeed < -3.0) return const Color(0xFF10B981);
    return const Color(0xFF3B82F6);
  }

  IconData get trendIcon {
    if (risingSpeed > 15.0) return Icons.trending_up_rounded;
    if (risingSpeed > 3.0) return Icons.arrow_upward_rounded;
    if (risingSpeed < -3.0) return Icons.trending_down_rounded;
    return Icons.trending_flat_rounded;
  }

  String get estimatedTimeToDangerText {
    if (isFloodDanger) {
      return 'อยู่ในระดับวิกฤตแล้ว (${waterLevel.toStringAsFixed(1)} / ${waterLevelThreshold.toStringAsFixed(1)} ซม.)';
    }
    if (risingSpeed > 2.0 && waterLevel < waterLevelThreshold) {
      final double diff = waterLevelThreshold - waterLevel;
      final double hours = diff / risingSpeed;
      final int minutes = (hours * 60).round();
      if (minutes < 60) {
        return 'คาดว่าจะถึงระดับวิกฤตในอีก ~$minutes นาที';
      } else {
        final int h = minutes ~/ 60;
        final int m = minutes % 60;
        return 'คาดว่าจะถึงระดับวิกฤตในอีก ~$h ชม. $m นาที';
      }
    }
    if (risingSpeed <= 0) {
      return 'สถานการณ์ทรงตัว / มีแนวโน้มลดลง';
    }
    return 'ระดับน้ำยังต่ำกว่าเกณฑ์วิกฤต';
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

  factory SosRequest.fromJson(String id, Map<dynamic, dynamic> json) => SosRequest(
        id: id,
        userName: json['userName']?.toString() ?? 'ผู้ประสบภัย',
        phoneNumber: json['phoneNumber']?.toString() ?? '-',
        lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : (double.tryParse(json['lat']?.toString() ?? '') ?? 0.0),
        lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : (double.tryParse(json['lng']?.toString() ?? '') ?? 0.0),
        situation: json['situation']?.toString() ?? 'ขอความช่วยเหลือด่วน',
        note: json['note']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] is num) ? (json['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
        ),
      );
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
  }) {
    bool updated = false;
    for (final device in _devices.values) {
      final double effectiveRainfall = precipitation > 0 ? precipitation : (prob30 >= 60 ? 15.0 : 0.0);
      if (device.rainfall != effectiveRainfall || device.weatherStatus != description) {
        device.rainfall = effectiveRainfall;
        device.weatherStatus = description;
        device.isRainingHeavy = effectiveRainfall >= 20.0 || prob30 >= 75;
        updated = true;
      }
    }
    if (updated) {
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

  SensorProvider() : _dbRef = FirebaseDatabase.instance.ref() {
    _loadAlertHistory();
    _initMockDevices();
    _initFirebaseListener();
    _initSosListener();
    _startHistoryTimer();
  }

  void _initSosListener() {
    try {
      _dbRef.child('sos_requests').onValue.listen((event) {
        if (!event.snapshot.exists) {
          _sosRequests = [];
          notifyListeners();
          return;
        }
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<SosRequest> loaded = [];
        data.forEach((key, val) {
          if (val is Map) {
            loaded.add(SosRequest.fromJson(key.toString(), val));
          }
        });
        loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _sosRequests = loaded;
        notifyListeners();
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
    final newRef = _dbRef.child('sos_requests').push();
    final item = SosRequest(
      id: newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userName: userName,
      phoneNumber: phoneNumber,
      lat: lat,
      lng: lng,
      situation: situation,
      note: note,
      status: 'pending',
      timestamp: DateTime.now(),
    );
    await newRef.set(item.toJson());
  }

  Future<void> updateSosStatus(String sosId, String newStatus) async {
    await _dbRef.child('sos_requests/$sosId/status').set(newStatus);
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
- อัตราการเปลี่ยนแปลง (RoC): ${device.risingSpeed >= 0 ? '+' : ''}${device.risingSpeed.toStringAsFixed(1)} ซม./ชม.
- แนวโน้ม: ${device.trendStatusText}
- การคาดการณ์: ${device.estimatedTimeToDangerText}

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
    _historyTimer?.cancel();
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
      'khlong_1': DeviceData(id: 'khlong_1', name: 'คลอง 1', lat: 13.7563, lng: 100.5018, waterLevel: 25.0, waterFlow: 8.0, batteryPercent: 92, batteryVoltage: 4.1, sensorHeight: 200.0),
      'khlong_2': DeviceData(id: 'khlong_2', name: 'คลอง 2', lat: 13.7600, lng: 100.5100, waterLevel: 58.0, waterFlow: 18.0, batteryPercent: 78, batteryVoltage: 3.8, sensorHeight: 250.0),
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
            if (deviceData['timestamp'] != null) {
              final int ts = (deviceData['timestamp'] is num) ? (deviceData['timestamp'] as num).toInt() : 0;
              if (ts > 0) {
                lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
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
              signalPercent: (deviceData['signalPercent'] is num) ? (deviceData['signalPercent'] as num).toInt() : 88,
              signalRssi: (deviceData['signalRssi'] is num) ? (deviceData['signalRssi'] as num).toInt() : -62,
              networkType: deviceData['networkType']?.toString() ?? '4G LTE / Wi-Fi',
              pingMs: (deviceData['pingMs'] is num) ? (deviceData['pingMs'] as num).toInt() : 24,
              batteryPercent: currentBatteryPercent,
              batteryVoltage: currentBatteryVoltage,
              sensorHeight: currentSensorHeight,
              isOnline: isOnline,
              lastSeen: lastSeen,
              boardModel: deviceData['boardModel']?.toString() ?? 'ESP32-WROOM-32',
              firmware: deviceData['firmware']?.toString() ?? 'v2.0-auto',
              modules: modules,
            );
          });
          _devices.clear();
          _devices.addAll(newDevices);
        }
          if (!_devices.containsKey(_selectedDeviceId) && _devices.isNotEmpty) {
            _selectedDeviceId = _devices.keys.first;
          }
          
          _isFirebaseInitialized = true;
          _checkAndTriggerNotifications();
          notifyListeners();
          
          for (var id in _devices.keys) {
            if (!_historyFetchedDeviceIds.contains(id)) {
              fetchDeviceHistory(id);
            }
          }
      });
    } catch (e) {
      debugPrint("Firebase not configured yet: $e");
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
  FloodWarningLevel get floodWarningLevel => currentDevice?.floodWarningLevel ?? FloodWarningLevel.safe;
  String get systemStatus => currentDevice?.systemStatus ?? 'รอข้อมูล...';
  bool get isDeviceOnline => currentDevice?.isDeviceOnline ?? true;

  void selectDevice(String deviceId) {
    if (_devices.containsKey(deviceId)) {
      _selectedDeviceId = deviceId;
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

    _checkAndTriggerNotifications();
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

  void _checkAndTriggerNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return; // Do not trigger local push notifications for guests
    }

    for (var device in _devices.values) {
      bool lastLeakage = _notifiedLeakageState[device.id] ?? false;
      if (device.isElectricalLeakage && !lastLeakage) {
        _triggerLeakageNotification(device);
        _notifiedLeakageState[device.id] = true;
      } else if (!device.isElectricalLeakage) {
        _notifiedLeakageState[device.id] = false;
      }

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

  Future<void> fetchDeviceHistory(String deviceId, {bool force = false}) async {
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

      final data = snapshot.value;
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

          if (ts > 0) {
            rawData.add({
              'timestamp': ts,
              'waterLevel': wl,
              'rainfall': rf,
              'waterFlow': wf,
            });
          }
        }
      });

      if (rawData.isNotEmpty) {
        rawData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

        final now = DateTime.now().millisecondsSinceEpoch;
        final oneDayMs = 24 * 60 * 60 * 1000;
        final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

        final h24 = rawData.where((e) => now - e['timestamp'] <= oneDayMs).toList();
        List<Map<String, dynamic>> h7d = rawData.where((e) => now - e['timestamp'] <= sevenDaysMs).toList();

        if (h24.isNotEmpty) {
          _deviceHistory24h[deviceId] = h24;
        }

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
            };
          }).toList();
          h7d.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        }

        if (h7d.isNotEmpty) {
          _deviceHistory7d[deviceId] = h7d;
        }
      }
    } catch (e) {
      debugPrint("Error fetching history for $deviceId: $e");
    } finally {
      if (_isLoadingHistory) {
        _isLoadingHistory = false;
        notifyListeners();
      }
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
