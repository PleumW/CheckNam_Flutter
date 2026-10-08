import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  static bool _isMockEnabled = false;
  static Map<String, dynamic>? _mockWeatherData;

  static bool get isMockEnabled => _isMockEnabled;
  static Map<String, dynamic>? get mockWeatherData => _mockWeatherData;

  static const String _prefMockEnabledKey = 'mock_weather_enabled';
  static const String _prefMockDataKey = 'mock_weather_data';

  /// ดึงค่าการจำลองสภาพอากาศที่เคยบันทึกไว้ในเครื่อง
  static Future<void> initMockState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMockEnabled = prefs.getBool(_prefMockEnabledKey) ?? false;
      final rawData = prefs.getString(_prefMockDataKey);
      if (rawData != null) {
        _mockWeatherData = json.decode(rawData);
      }
    } catch (_) {}
  }

  /// ชุดข้อมูลจำลองสำเร็จรูป (Presets) สำหรับการนำเสนอและการทดสอบ
  static const Map<String, Map<String, dynamic>> presets = {
    'sunny': {
      'label': '☀️ แดดจัด / ปลอดฝน (Sunny)',
      'description': 'ท้องฟ้าแจ่มใส ไม่มีฝน',
      'icon': '☀️',
      'temperature': 33.0,
      'precipitation': 0.0,
      'prob30': 5,
      'prob60': 10,
      'prob90': 10,
    },
    'cloudy': {
      'label': '⛅ มีเมฆ / เสี่ยงฝนตกปรอยๆ (Cloudy)',
      'description': 'มีเมฆมาก โอกาสฝนตกปรอยๆ',
      'icon': '🌦️',
      'temperature': 29.0,
      'precipitation': 4.5,
      'prob30': 45,
      'prob60': 40,
      'prob90': 30,
    },
    'heavy_rain': {
      'label': '🌧️ ฝนตกหนักปานกลาง (Heavy Rain)',
      'description': 'ฝนตกหนักในพื้นที่ เสี่ยงน้ำเอ่อท่วม',
      'icon': '🌧️',
      'temperature': 26.0,
      'precipitation': 25.0,
      'prob30': 75,
      'prob60': 70,
      'prob90': 60,
    },
    'storm_critical': {
      'label': '⛈️ พายุฝนวิกฤต (Severe Storm - เตือนภัยฉุกเฉิน)',
      'description': 'พายุฝนฟ้าคะนองรุนแรง วิกฤตน้ำท่วมฉับพลัน',
      'icon': '⛈️',
      'temperature': 24.0,
      'precipitation': 55.0,
      'prob30': 95,
      'prob60': 90,
      'prob90': 85,
    },
  };

  /// บันทึกค่าจำลองสภาพอากาศ
  static Future<void> setMockWeather({
    required double temperature,
    required double precipitation,
    required String description,
    required String icon,
    required int prob30,
    required int prob60,
    required int prob90,
  }) async {
    _isMockEnabled = true;
    _mockWeatherData = {
      'temperature': temperature,
      'precipitation': precipitation,
      'description': description,
      'icon': icon,
      'prob30': prob30,
      'prob60': prob60,
      'prob90': prob90,
      'isMock': true,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefMockEnabledKey, true);
      await prefs.setString(_prefMockDataKey, json.encode(_mockWeatherData));
    } catch (_) {}
  }

  /// ใช้งานค่าพยากรณ์จำลองตาม Preset Key
  static Future<void> setMockPreset(String presetKey) async {
    final preset = presets[presetKey] ?? presets['heavy_rain']!;
    await setMockWeather(
      temperature: (preset['temperature'] as num).toDouble(),
      precipitation: (preset['precipitation'] as num).toDouble(),
      description: preset['description'] as String,
      icon: preset['icon'] as String,
      prob30: preset['prob30'] as int,
      prob60: preset['prob60'] as int,
      prob90: preset['prob90'] as int,
    );
  }

  /// ปิดการจำลองสภาพอากาศ และคืนค่าสู่ Open-Meteo API จริง
  static Future<void> clearMock() async {
    _isMockEnabled = false;
    _mockWeatherData = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefMockEnabledKey, false);
      await prefs.remove(_prefMockDataKey);
    } catch (_) {}
  }

  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};

  // ใช้ Open-Meteo API (ฟรี ไม่ต้องใช้ API Key)
  static Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    // 💡 หากเปิดโหมดจำลองสภาพอากาศ (Mockup Mode) ให้คืนค่าจำลองทันทีโดยไม่ต้องเรียก API ภายนอก (มั่นคง 100% ไม่แกว่ง)
    if (_isMockEnabled && _mockWeatherData != null) {
      return Map<String, dynamic>.from(_mockWeatherData!);
    }

    final cacheKey = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
    final now = DateTime.now();
    if (_cache.containsKey(cacheKey) && _cacheTime.containsKey(cacheKey)) {
      if (now.difference(_cacheTime[cacheKey]!).inMinutes < 10) {
        return Map<String, dynamic>.from(_cache[cacheKey]!);
      }
    }

    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,precipitation,weather_code&hourly=precipitation_probability&timezone=Asia/Bangkok');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final current = data['current'];
        final temperature = current['temperature_2m'];
        final precipitation = current['precipitation'];
        final weatherCode = current['weather_code'];
        
        int prob30 = 10;
        int prob60 = 15;
        int prob90 = 20;

        try {
          final hourlyProb = data['hourly']?['precipitation_probability'] as List?;
          if (hourlyProb != null && hourlyProb.isNotEmpty) {
            prob30 = (hourlyProb[0] as num).toInt();
            prob60 = hourlyProb.length > 1 ? (hourlyProb[1] as num).toInt() : prob30;
            prob90 = hourlyProb.length > 2 ? (hourlyProb[2] as num).toInt() : prob60;
          }
        } catch (_) {}

        String description = 'ท้องฟ้าแจ่มใส';
        String icon = '☀️';
        
        if (weatherCode >= 1 && weatherCode <= 3) {
          description = 'มีเมฆบางส่วน';
          icon = '⛅';
        } else if (weatherCode >= 51 && weatherCode <= 67) {
          description = 'ฝนตกปรอยๆ';
          icon = '🌧️';
        } else if (weatherCode >= 71 && weatherCode <= 82) {
          description = 'ฝนตกหนัก';
          icon = '⛈️';
        }

        final result = {
          'temperature': temperature,
          'precipitation': precipitation,
          'description': description,
          'icon': icon,
          'prob30': prob30,
          'prob60': prob60,
          'prob90': prob90,
          'isMock': false,
        };

        _cache[cacheKey] = result;
        _cacheTime[cacheKey] = now;
        return result;
      }
      if (_cache.containsKey(cacheKey)) {
        return Map<String, dynamic>.from(_cache[cacheKey]!);
      }
      return {};
    } catch (e) {
      if (_cache.containsKey(cacheKey)) {
        return Map<String, dynamic>.from(_cache[cacheKey]!);
      }
      return {};
    }
  }
}
