import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('Dashboard Layout Safety & Overflow Prevention Tests', () {
    test('Station forecast label is concise and does not overflow header row', () {
      const stationTitle = 'พยากรณ์ฝนล่วงหน้า (สถานี IoT)';
      expect(stationTitle.length, lessThanOrEqualTo(35));
    });

    test('floodRiskProbability returns low percent for normal water level and zero rain', () {
      final safeDevice = DeviceData(
        id: 'safe_dev',
        name: 'สถานีปลอดภัย',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 10.0,
        waterLevelThreshold: 60.0,
        risingSpeed: 0.0,
        rainfall: 0.0,
        forecastRainProb30: 10,
        forecastRainProb60: 15,
        isOnline: true,
        lastDataReceived: DateTime.now(),
      );

      expect(safeDevice.floodRiskProbability30, lessThan(20));
      expect(safeDevice.floodRiskProbability60, lessThan(20));
    });

    test('floodRiskProbability elevates when water nears danger threshold', () {
      final elevatedDevice = DeviceData(
        id: 'elevated_dev',
        name: 'สถานีเฝ้าระวัง',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 45.0,
        waterLevelThreshold: 60.0,
        risingSpeed: 4.0,
        rainfall: 5.0,
        forecastRainProb30: 50,
        forecastRainProb60: 60,
        isOnline: true,
        lastDataReceived: DateTime.now(),
      );

      expect(elevatedDevice.floodRiskProbability30, greaterThanOrEqualTo(40));
      expect(elevatedDevice.floodRiskProbability60, greaterThanOrEqualTo(45));
    });

    test('floodRiskProbability triggers critical (>= 85%) when predicted level reaches threshold', () {
      final dangerDevice = DeviceData(
        id: 'danger_dev',
        name: 'สถานีวิกฤต',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 55.0,
        waterLevelThreshold: 60.0,
        risingSpeed: 15.0,
        rainfall: 20.0,
        forecastRainProb30: 80,
        forecastRainProb60: 90,
        isOnline: true,
        lastDataReceived: DateTime.now(),
      );

      expect(dangerDevice.predictedWaterLevel30 >= dangerDevice.waterLevelThreshold, isTrue);
      expect(dangerDevice.floodRiskProbability30, greaterThanOrEqualTo(85));
      expect(dangerDevice.floodRiskProbability60, greaterThanOrEqualTo(85));
    });

    test('floodRiskProbability returns 0 when device is offline', () {
      final offlineDevice = DeviceData(
        id: 'offline_dev',
        name: 'สถานีออฟไลน์',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 55.0,
        waterLevelThreshold: 60.0,
        isOnline: false,
      );

      expect(offlineDevice.floodRiskProbability30, equals(0));
      expect(offlineDevice.floodRiskProbability60, equals(0));
    });
  });
}
