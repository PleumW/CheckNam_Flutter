import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('Early Warning Sensor & Weather Forecast Fusion Tests', () {
    test('Default values for forecast probabilities', () {
      final device = DeviceData(
        id: 'test_1',
        name: 'สถานีทดสอบ',
        lat: 13.75,
        lng: 100.50,
      );

      expect(device.forecastRainProb30, 20);
      expect(device.forecastRainProb60, 30);
      expect(device.forecastRainProb90, 15);
      expect(device.earlyWarningSeverity, EarlyWarningSeverity.none);
    });

    test('Compound speed combines ultrasonic RoC + rainfall + forecast impact', () {
      final device = DeviceData(
        id: 'test_1',
        name: 'สถานีทดสอบ',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 25.0,
        risingSpeed: 5.0,
        rainfall: 10.0,
        forecastRainProb30: 70,
      );

      // sensorRate = 5.0
      // rainImpact = 10.0 * 0.3 = 3.0
      // forecastImpact = 4.5 * (70 / 100) = 3.15
      // total = 5.0 + 3.0 + 3.15 = 11.15 -> 11.2 cm/h
      expect(device.compoundRisingSpeed, 11.2);
    });

    test('Critical severity triggers when compound speed >= 12.0 and high rain probability', () {
      final device = DeviceData(
        id: 'test_critical',
        name: 'สถานีวิกฤต',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 25.0,
        waterLevelThreshold: 50.0,
        risingSpeed: 6.0,
        rainfall: 15.0, // 15 * 0.3 = 4.5
        forecastRainProb30: 80, // 4.5 * 0.8 = 3.6 -> total = 6 + 4.5 + 3.6 = 14.1 cm/h
        lastDataReceived: DateTime.now(),
      );

      expect(device.compoundRisingSpeed >= 12.0, isTrue);
      expect(device.earlyWarningSeverity, EarlyWarningSeverity.critical);
      expect(device.isEarlyWarning, isTrue);
      expect(device.smartEarlyWarningTitle, contains('เตือนภัยล่วงหน้าขั้นวิกฤต'));
      expect(device.systemStatus, contains('วิกฤตเตือนภัยล่วงหน้า'));
    });

    test('Alert severity triggers when rising speed is high or moderate compound with rain', () {
      final device = DeviceData(
        id: 'test_alert',
        name: 'สถานีเฝ้าระวังด่วน',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 25.0,
        waterLevelThreshold: 50.0,
        risingSpeed: 3.0,
        rainfall: 5.0, // 5 * 0.3 = 1.5
        forecastRainProb30: 60, // 2.0 -> total = 3 + 1.5 + 2.0 = 6.5 cm/h >= 6.0 and prob30 >= 60
        lastDataReceived: DateTime.now(),
      );

      expect(device.earlyWarningSeverity, EarlyWarningSeverity.alert);
      expect(device.isEarlyWarning, isTrue);
      expect(device.smartEarlyWarningTitle, contains('เตือนภัยล่วงหน้า'));
      expect(device.systemStatus, contains('เตือนภัยล่วงหน้า'));
    });

    test('Advisory severity triggers on rain forecast >= 65%', () {
      final device = DeviceData(
        id: 'test_advisory',
        name: 'สถานีเฝ้าระวังฝน',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 10.0,
        risingSpeed: 0.0,
        rainfall: 0.0,
        forecastRainProb30: 65,
        lastDataReceived: DateTime.now(),
      );

      expect(device.earlyWarningSeverity, EarlyWarningSeverity.advisory);
      expect(device.isEarlyWarning, isFalse); // Advisory is not yet alert/critical
      expect(device.smartEarlyWarningTitle, contains('เฝ้าระวังล่วงหน้า'));
    });

    test('Compound time to danger accounts for combined compound speed', () {
      final device = DeviceData(
        id: 'test_time',
        name: 'สถานีคำนวณเวลา',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 20.0,
        waterLevelThreshold: 40.0, // diff = 20 cm
        risingSpeed: 4.0,
        rainfall: 10.0, // 3.0
        forecastRainProb30: 70, // 3.15 -> compound = 10.15 -> 10.2 cm/h
        lastDataReceived: DateTime.now(),
      );

      // diff = 20 cm, speed = 10.2 cm/h -> hours = 20 / 10.2 = ~1.96 hours (~118 minutes -> 1 ชม. 58 นาที)
      final timeText = device.compoundTimeToDangerText;
      expect(timeText, contains('คาดว่าจะถึงระดับวิกฤตในอีก ~'));
      expect(timeText, contains('รวมฝน'));
    });

    test('Proactive water level forecast calculates 30-min and 60-min projections', () {
      final device = DeviceData(
        id: 'test_forecast',
        name: 'สถานีพยากรณ์',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 30.0,
        waterLevelThreshold: 50.0,
        risingSpeed: 4.0,
        rainfall: 10.0, // 3.0
        forecastRainProb30: 70, // 3.15 -> compoundRisingSpeed = 10.2
        lastDataReceived: DateTime.now(),
      );

      // compoundRisingSpeed = 10.2
      // 30 min projection: 30.0 + (10.2 * 0.5) = 35.1 cm -> Danger (Critical 30-49.9 cm)
      // 60 min projection: 30.0 + (10.2 * 1.0) = 40.2 cm -> Danger (Critical 30-49.9 cm)
      expect(device.predictedWaterLevel30, 35.1);
      expect(device.predictedWaterLevel60, 40.2);
      expect(device.predictedWarningLevel30, FloodWarningLevel.danger);
      expect(device.predictedWarningLevel60, FloodWarningLevel.danger);
      expect(device.proactiveForecastSummary, contains('อีก 30 นาที คาดระดับน้ำเพิ่มเป็น 35.1 ซม.'));
      expect(device.proactiveForecastSummary, contains('ร่วมกับโอกาสฝน 70%'));
    });

    test('Proactive water level forecast returns 0 and offline notice when device is offline', () {
      final device = DeviceData(
        id: 'test_offline',
        name: 'สถานีออฟไลน์',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 45.0,
        isOnline: false,
      );

      expect(device.predictedWaterLevel30, 0.0);
      expect(device.predictedWaterLevel60, 0.0);
      expect(device.proactiveForecastSummary, contains('อุปกรณ์ออฟไลน์'));
    });
  });
}
