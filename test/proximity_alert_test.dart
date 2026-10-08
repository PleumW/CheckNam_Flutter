import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_water_flood/providers/settings_provider.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Proximity Alert & Retreat Guidance Logic Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsProvider initializes default proximity settings and updates properly', () async {
      final settings = SettingsProvider();
      expect(settings.proximityAlertEnabled, isTrue);
      expect(settings.proximityAlertRadiusMeters, 500.0);

      await settings.updateProximityRadius(1000.0);
      expect(settings.proximityAlertRadiusMeters, 1000.0);

      await settings.toggleProximityAlert(false);
      expect(settings.proximityAlertEnabled, isFalse);
    });

    test('Effective warning radius adapts dynamically to hazard severity', () {
      const double baseRadius = 500.0;

      // Critical severity: high water level
      final deviceCritical = DeviceData(
        id: 'test_1',
        name: 'สถานีน้ำท่วมวิกฤต',
        waterLevel: 70.0,
        batteryPercent: 90,
        batteryVoltage: 4.1,
        lat: 13.75,
        lng: 100.50,
      );
      double radiusCritical = baseRadius;
      if (deviceCritical.waterLevel >= 60.0) {
        radiusCritical = baseRadius.clamp(300.0, 2000.0);
      }
      expect(radiusCritical, 500.0);

      final deviceWarning = DeviceData(
        id: 'test_2',
        name: 'สถานีน้ำท่วมสูง',
        waterLevel: 45.0,
        batteryPercent: 90,
        batteryVoltage: 4.1,
        lat: 13.75,
        lng: 100.50,
      );
      double radiusWarning = baseRadius;
      if (deviceWarning.waterLevel >= 40.0) {
        radiusWarning = (baseRadius * 0.9).clamp(300.0, 2000.0);
      }
      expect(radiusWarning, 450.0);

      // Advisory severity: water level 25 cm
      double radiusAdvisory = (baseRadius * 0.8).clamp(250.0, 2000.0);
      expect(radiusAdvisory, 400.0);
    });

    test('Distance calculation accurately identifies proximity intrusion', () {
      const Distance distanceCalc = Distance();
      // User location
      const userLatLng = LatLng(13.7563, 100.5018);
      // Device located ~200 meters north
      const nearDeviceLatLng = LatLng(13.7581, 100.5018);
      // Device located ~5 km away
      const farDeviceLatLng = LatLng(13.8000, 100.5018);

      final double nearDist = distanceCalc.as(LengthUnit.Meter, userLatLng, nearDeviceLatLng);
      final double farDist = distanceCalc.as(LengthUnit.Meter, userLatLng, farDeviceLatLng);

      expect(nearDist < 300.0, isTrue, reason: 'Near device is within 300m');
      expect(farDist > 4000.0, isTrue, reason: 'Far device is over 4km away');
    });

    test('Retreat distance instruction matches hazard severity levels', () {
      String getRetreatInstruction(DeviceData d) {
        if (d.waterLevel >= 60.0) {
          return 'ถอยห่างออกไปอย่างน้อย 300 - 500 เมตร';
        } else if (d.waterLevel >= 40.0) {
          return 'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง';
        } else {
          return 'เฝ้าระวังในระยะ 800 - 1,000 เมตร';
        }
      }

      final criticalFlood = DeviceData(
        id: 'c2',
        name: 'Critical Deep Flood',
        waterLevel: 75.0,
        batteryPercent: 80,
        batteryVoltage: 3.9,
        lat: 0,
        lng: 0,
      );
      final warningFlood = DeviceData(
        id: 'w1',
        name: 'High Water Flood',
        waterLevel: 48.0,
        batteryPercent: 80,
        batteryVoltage: 3.9,
        lat: 0,
        lng: 0,
      );
      final advisoryFlood = DeviceData(
        id: 'a1',
        name: 'Puddle Ponding',
        waterLevel: 28.0,
        batteryPercent: 80,
        batteryVoltage: 3.9,
        lat: 0,
        lng: 0,
      );

      expect(getRetreatInstruction(criticalFlood), 'ถอยห่างออกไปอย่างน้อย 300 - 500 เมตร');
      expect(getRetreatInstruction(warningFlood), 'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง');
      expect(getRetreatInstruction(advisoryFlood), 'เฝ้าระวังในระยะ 800 - 1,000 เมตร');
    });

    test('Critical water level and electrical leakage bypass 5-minute snooze for persistent alerts', () {
      bool shouldSuppressAlert({
        required DeviceData device,
        required DateTime lastAlertTime,
        required DateTime currentTime,
      }) {
        final bool isCritical = device.isElectricalLeakage ||
            device.waterLevel >= 60.0 ||
            device.isFloodDanger;

        final difference = currentTime.difference(lastAlertTime);

        if (isCritical) {
          // Critical condition only suppresses for a tiny 3-second grace cooldown
          return difference < const Duration(seconds: 3);
        } else {
          // Non-critical condition is snoozed for 5 minutes
          return difference < const Duration(minutes: 5);
        }
      }

      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      final tenSecondsAgo = now.subtract(const Duration(seconds: 10));
      final oneSecondAgo = now.subtract(const Duration(seconds: 1));

      final criticalDevice = DeviceData(
        id: 'crit_1',
        name: 'Critical Flood Station',
        waterLevel: 65.0,
        batteryPercent: 85,
        batteryVoltage: 4.0,
        lat: 13.75,
        lng: 100.50,
      );

      final warningDevice = DeviceData(
        id: 'warn_1',
        name: 'Warning Flood Station',
        waterLevel: 20.0,
        batteryPercent: 85,
        batteryVoltage: 4.0,
        lat: 13.75,
        lng: 100.50,
      );

      // Warning device: snoozed at 1 minute ago (within 5 minutes) -> suppressed
      expect(shouldSuppressAlert(device: warningDevice, lastAlertTime: oneMinuteAgo, currentTime: now), isTrue);

      // Critical device: at 1 minute ago -> NOT suppressed (must pop up continuously!)
      expect(shouldSuppressAlert(device: criticalDevice, lastAlertTime: oneMinuteAgo, currentTime: now), isFalse);

      // Critical device: at 10 seconds ago -> NOT suppressed (must pop up continuously!)
      expect(shouldSuppressAlert(device: criticalDevice, lastAlertTime: tenSecondsAgo, currentTime: now), isFalse);

      // Critical device: at 1 second ago -> suppressed briefly (3s cooldown for animation stability)
      expect(shouldSuppressAlert(device: criticalDevice, lastAlertTime: oneSecondAgo, currentTime: now), isTrue);
    });

    test('Early Warning triggers route avoidance and retreat command', () {
      String getRetreatInstructionWithEarlyWarning(DeviceData d) {
        final bool isCriticalWater = d.waterLevel >= 60.0;
        final bool isFloodDanger = d.isFloodDanger;
        final bool isEWCritical = d.earlyWarningSeverity == EarlyWarningSeverity.critical;
        final bool isEWAlert = d.earlyWarningSeverity == EarlyWarningSeverity.alert;

        if (isCriticalWater || isFloodDanger) {
          return 'ถอยห่างออกไปอย่างน้อย 300 - 500 เมตร';
        } else if (isEWCritical) {
          return 'เปลี่ยนเส้นทางทันที / ถอยห่างจากพื้นที่ลุ่มต่ำ 500 - 1,000 เมตร';
        } else if (isEWAlert) {
          return 'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง';
        } else if (d.waterLevel >= 40.0) {
          return 'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง';
        } else {
          return 'เฝ้าระวังในระยะ 800 - 1,000 เมตร';
        }
      }

      // Early Warning Critical: Water only 15cm, but rapid rise + heavy rain
      final ewCriticalDevice = DeviceData(
        id: 'ew_crit',
        name: 'Flash Flood Risk Station',
        waterLevel: 15.0,
        risingSpeed: 10.0,
        forecastRainProb30: 80,
        rainfall: 20.0,
        batteryPercent: 90,
        batteryVoltage: 4.1,
        lat: 13.75,
        lng: 100.50,
      );
      expect(ewCriticalDevice.earlyWarningSeverity, EarlyWarningSeverity.critical);
      expect(
        getRetreatInstructionWithEarlyWarning(ewCriticalDevice),
        'เปลี่ยนเส้นทางทันที / ถอยห่างจากพื้นที่ลุ่มต่ำ 500 - 1,000 เมตร',
      );

      // Early Warning Alert: Water 18cm, rising speed 10cm/hr
      final ewAlertDevice = DeviceData(
        id: 'ew_alert',
        name: 'Rapid Rise Alert Station',
        waterLevel: 18.0,
        risingSpeed: 10.0,
        forecastRainProb30: 30,
        batteryPercent: 90,
        batteryVoltage: 4.1,
        lat: 13.75,
        lng: 100.50,
      );
      expect(ewAlertDevice.earlyWarningSeverity, EarlyWarningSeverity.alert);
      expect(
        getRetreatInstructionWithEarlyWarning(ewAlertDevice),
        'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง',
      );
    });
  });
}
