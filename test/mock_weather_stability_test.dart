import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_water_flood/providers/weather_service.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeatherService.clearMock();
  });

  group('Mock Weather Stability and Anti-Fluctuation Tests', () {
    test('Mock weather returns consistent and unfluctuating values across multiple fetches', () async {
      await WeatherService.setMockPreset('cloudy');
      expect(WeatherService.isMockEnabled, isTrue);

      final fetch1 = await WeatherService.fetchWeather(13.7563, 100.5018);
      final fetch2 = await WeatherService.fetchWeather(13.7563, 100.5018);
      final fetch3 = await WeatherService.fetchWeather(14.0000, 100.6000);

      expect(fetch1['prob30'], equals(45));
      expect(fetch1['prob60'], equals(40));
      expect(fetch1['prob90'], equals(30));
      expect(fetch1['precipitation'], equals(4.5));

      // Must be completely identical across fetches without swinging
      expect(fetch1['prob30'], equals(fetch2['prob30']));
      expect(fetch2['prob30'], equals(fetch3['prob30']));
      expect(fetch1['precipitation'], equals(fetch2['precipitation']));
    });

    test('updateRainfallFromWeatherApi retains exact 0.0 mm rainfall in mock mode without synthesizing 15 mm', () {
      final provider = SensorProvider();
      
      // Enable mock sunny preset (0 mm rain)
      WeatherService.setMockWeather(
        temperature: 33.0,
        precipitation: 0.0,
        description: 'แดดจัด ไม่มีฝน',
        icon: '☀️',
        prob30: 65, // high probability but 0 mm rain
        prob60: 50,
        prob90: 30,
      );

      final dev = provider.currentDevice;
      expect(dev, isNotNull);

      provider.updateRainfallFromWeatherApi(
        deviceId: dev!.id,
        precipitation: 0.0,
        description: 'แดดจัด ไม่มีฝน',
        prob30: 65,
        prob60: 50,
        prob90: 30,
      );

      // In mock mode, 0.0 mm MUST stay 0.0 mm and not fluctuate to 15.0 mm
      expect(dev.rainfall, equals(0.0));
      expect(dev.forecastRainProb30, equals(65));
      expect(dev.forecastRainProb60, equals(50));
    });

    test('Heavy rain preset keeps forecast probability and severity stable', () async {
      await WeatherService.setMockPreset('heavy_rain');
      final data = await WeatherService.fetchWeather(13.7563, 100.5018);

      expect(data['prob30'], equals(75));
      expect(data['prob60'], equals(70));
      expect(data['precipitation'], equals(25.0));

      final dev = DeviceData(
        id: 'test_dev',
        name: 'สถานีทดสอบ',
        lat: 13.7563,
        lng: 100.5018,
        waterLevel: 20.0,
        waterLevelThreshold: 50.0,
        rainfall: (data['precipitation'] as num).toDouble(),
        forecastRainProb30: data['prob30'] as int,
        forecastRainProb60: data['prob60'] as int,
        isOnline: true,
      );

      expect(dev.forecastRainProb30, equals(75));
      expect(dev.rainfall, equals(25.0));
      expect(dev.compoundRisingSpeed, greaterThan(7.0));
      expect(dev.earlyWarningSeverity, isNot(equals(EarlyWarningSeverity.none)));
    });

    test('Clearing mock weather resets isMockEnabled cleanly', () async {
      await WeatherService.setMockPreset('storm_critical');
      expect(WeatherService.isMockEnabled, isTrue);

      await WeatherService.clearMock();
      expect(WeatherService.isMockEnabled, isFalse);
      expect(WeatherService.mockWeatherData, isNull);
    });
  });
}
