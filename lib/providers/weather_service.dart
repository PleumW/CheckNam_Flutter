import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // ใช้ Open-Meteo API (ฟรี ไม่ต้องใช้ API Key)
  static Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
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

        return {
          'temperature': temperature,
          'precipitation': precipitation,
          'description': description,
          'icon': icon,
          'prob30': prob30,
          'prob60': prob60,
          'prob90': prob90,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
