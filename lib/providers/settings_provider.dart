import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WidgetSizeMode { full, compact }

class DashboardWidgetConfig {
  final String id;
  final String title;
  final IconData icon;
  bool isVisible;
  WidgetSizeMode sizeMode;

  DashboardWidgetConfig({
    required this.id,
    required this.title,
    required this.icon,
    this.isVisible = true,
    this.sizeMode = WidgetSizeMode.full,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'isVisible': isVisible,
        'sizeMode': sizeMode.name,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json, DashboardWidgetConfig defaultConfig) {
    WidgetSizeMode parsedMode = defaultConfig.sizeMode;
    if (json.containsKey('sizeMode')) {
      final String modeStr = json['sizeMode'];
      parsedMode = WidgetSizeMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => defaultConfig.sizeMode,
      );
    } else if (json['isCompact'] == true) {
      parsedMode = WidgetSizeMode.compact;
    }

    return DashboardWidgetConfig(
      id: defaultConfig.id,
      title: defaultConfig.title,
      icon: defaultConfig.icon,
      isVisible: json['isVisible'] ?? defaultConfig.isVisible,
      sizeMode: parsedMode,
    );
  }
}

class SettingsProvider with ChangeNotifier {
  String _emergencyNumber = '1669';
  String _appLanguage = 'TH';
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  List<DashboardWidgetConfig> _dashboardWidgets = _getDefaultWidgetList();

  SettingsProvider() {
    _loadSettings();
  }

  String get emergencyNumber => _emergencyNumber;
  String get appLanguage => _appLanguage;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  List<DashboardWidgetConfig> get dashboardWidgets => _dashboardWidgets;

  static List<DashboardWidgetConfig> _getDefaultWidgetList() {
    return [
      DashboardWidgetConfig(id: 'weather_header', title: 'สภาพอากาศตำแหน่งปัจจุบัน', icon: Icons.cloud_rounded),
      DashboardWidgetConfig(id: 'risk_distance', title: 'รัศมีเสี่ยงภัยพิบัติ', icon: Icons.shield_rounded),
      DashboardWidgetConfig(id: 'status', title: 'สถานะความปลอดภัยรวม', icon: Icons.security_rounded),
      DashboardWidgetConfig(id: 'water_level', title: 'ระดับน้ำปัจจุบัน', icon: Icons.water_drop_rounded),
      DashboardWidgetConfig(id: 'electricity', title: 'กระแสไฟฟ้า', icon: Icons.bolt_rounded),
      DashboardWidgetConfig(id: 'weather_status', title: 'สภาพอากาศรายวัน', icon: Icons.cloud_queue_rounded),
      DashboardWidgetConfig(id: 'water_speed', title: 'ความเร็วการเพิ่มระดับน้ำ', icon: Icons.speed_rounded),
      DashboardWidgetConfig(id: 'rain_forecast', title: 'พยากรณ์ฝนล่วงหน้า', icon: Icons.umbrella_rounded),
      DashboardWidgetConfig(id: 'device_signal', title: 'สัญญาณอินเทอร์เน็ตอุปกรณ์', icon: Icons.cell_tower_rounded),
    ];
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _emergencyNumber = prefs.getString('emergencyNumber') ?? '1669';
    _appLanguage = prefs.getString('appLanguage') ?? 'TH';
    
    if (prefs.containsKey('soundEnabled')) {
      _soundEnabled = prefs.getBool('soundEnabled')!;
    }
    if (prefs.containsKey('vibrationEnabled')) {
      _vibrationEnabled = prefs.getBool('vibrationEnabled')!;
    }

    final savedLayoutJson = prefs.getString('dashboardLayoutConfig');
    if (savedLayoutJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(savedLayoutJson);
        final defaultMap = {for (var w in _getDefaultWidgetList()) w.id: w};
        List<DashboardWidgetConfig> loadedList = [];
        for (var item in jsonList) {
          final id = item['id'];
          if (defaultMap.containsKey(id)) {
            loadedList.add(DashboardWidgetConfig.fromJson(item, defaultMap[id]!));
            defaultMap.remove(id);
          }
        }
        // Add any new default widgets missing from saved layout
        loadedList.addAll(defaultMap.values);
        _dashboardWidgets = loadedList;
      } catch (_) {
        _dashboardWidgets = _getDefaultWidgetList();
      }
    }
    notifyListeners();
  }

  Future<void> _saveDashboardLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_dashboardWidgets.map((w) => w.toJson()).toList());
    await prefs.setString('dashboardLayoutConfig', jsonString);
  }

  void reorderDashboardWidgets(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _dashboardWidgets.removeAt(oldIndex);
    _dashboardWidgets.insert(newIndex, item);
    _saveDashboardLayout();
    notifyListeners();
  }

  void cycleWidgetSizeMode(String id) {
    final index = _dashboardWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      _dashboardWidgets[index].sizeMode = _dashboardWidgets[index].sizeMode == WidgetSizeMode.full
          ? WidgetSizeMode.compact
          : WidgetSizeMode.full;
      _saveDashboardLayout();
      notifyListeners();
    }
  }

  void toggleWidgetVisibility(String id) {
    final index = _dashboardWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      _dashboardWidgets[index].isVisible = !_dashboardWidgets[index].isVisible;
      _saveDashboardLayout();
      notifyListeners();
    }
  }

  void resetDashboardLayout() {
    _dashboardWidgets = _getDefaultWidgetList();
    _saveDashboardLayout();
    notifyListeners();
  }

  Future<void> updateEmergencyNumber(String number) async {
    if (number.isNotEmpty) {
      _emergencyNumber = number;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergencyNumber', number);
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    _appLanguage = _appLanguage == 'TH' ? 'EN' : 'TH';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLanguage', _appLanguage);
    notifyListeners();
  }

  Future<void> toggleSound(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', value);
    notifyListeners();
  }

  Future<void> toggleVibration(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationEnabled', value);
    notifyListeners();
  }
}
