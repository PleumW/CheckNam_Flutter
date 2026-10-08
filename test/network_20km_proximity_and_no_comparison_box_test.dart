import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';
import 'package:flutter_application_water_flood/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('20km Network Mock Equipment Tests', () {
    test('SensorProvider initializes 8 mock stations distributed within 20km radius', () {
      final sensor = SensorProvider();
      final devices = sensor.devices;

      // Verify stations exist
      expect(devices.containsKey('station_upstream'), isTrue);
      expect(devices.containsKey('station_downstream'), isTrue);
      expect(devices.containsKey('station_bangsue'), isTrue);
      expect(devices.containsKey('station_bangkoknoi'), isTrue);
      expect(devices.containsKey('station_saensaep'), isTrue);
      expect(devices.containsKey('station_rama5'), isTrue);
      expect(devices.containsKey('station_phrapradaeng'), isTrue);
      expect(devices.containsKey('station_rangsit'), isTrue);

      // Verify stations have names and network properties
      final bangsue = devices['station_bangsue']!;
      expect(bangsue.name, contains('คลองบางซื่อ'));
      expect(bangsue.stationTypeName, contains('สถานีเครือข่าย (รัศมี 20 กม.)'));

      final saensaep = devices['station_saensaep']!;
      expect(saensaep.name, contains('คลองแสนแสบ'));

      final rangsit = devices['station_rangsit']!;
      expect(rangsit.name, contains('รังสิต'));
    });

    test('All mock stations are located within 20km of central station', () {
      final sensor = SensorProvider();
      final up = sensor.devices['station_upstream']!;

      for (final dev in sensor.devices.values) {
        // Compute distance to upstream station
        final double distMeters = _calcDist(up.lat, up.lng, dev.lat, dev.lng);
        expect(distMeters <= 20000.0, isTrue,
            reason: '${dev.name} (${dev.id}) distance is ${(distMeters / 1000).toStringAsFixed(2)} km, must be <= 20 km');
      }
    });
  });

  group('20km Inter-Device Proximity Flood Alert & Retreat Warning Tests', () {
    test('Flood at network station (e.g. Bangsue) alerts user monitoring downstream station within 20km', () {
      final sensor = SensorProvider();

      // User is monitoring downstream station
      sensor.selectDevice('station_downstream');
      expect(sensor.hasProximityFloodAlert, isFalse);

      // Simulate Bangsue canal flooding (85 cm > threshold 60 cm)
      sensor.simulateStationFlood('station_bangsue', waterLevel: 85.0);

      // Downstream station (~5.4 km from Bangsue) receives 20km crisis retreat alert
      expect(sensor.hasProximityFloodAlert, isTrue);
      expect(sensor.proximityFloodAlertMessage, isNotNull);
      expect(sensor.proximityFloodAlertMessage, contains('แจ้งเตือนภัยวิกฤตในรัศมี 20 กม.!'));
      expect(sensor.proximityFloodAlertMessage, contains('สถานีคลองบางซื่อ'));
      expect(sensor.proximityFloodAlertMessage, contains('ท่านอยู่ในรัศมีเสี่ยงภัย 20 กม. มีสถานะวิกฤติ โปรดออกห่างจากบริเวณนี้ทันที!'));
    });

    test('Flood at Rangsit sluice alerts upstream station 17km away with retreat notice', () {
      final sensor = SensorProvider();

      // User is monitoring central upstream station
      sensor.selectDevice('station_upstream');
      expect(sensor.hasProximityFloodAlert, isFalse);

      // Simulate Rangsit station flooding (88 cm > threshold 75 cm)
      sensor.simulateStationFlood('station_rangsit', waterLevel: 88.0);

      expect(sensor.hasProximityFloodAlert, isTrue);
      expect(sensor.proximityFloodAlertMessage, contains('รัศมี 20 กม.'));
      expect(sensor.proximityFloodAlertMessage, contains('โปรดออกห่างจากบริเวณนี้ทันที'));
    });
  });

  group('Removal of Dual-Station Water Level Comparison Box Tests', () {
    test('SettingsProvider default widget list does NOT contain dual_station or electricity comparison box', () {
      final settings = SettingsProvider();
      final widgetIds = settings.dashboardWidgets.map((w) => w.id).toList();

      expect(widgetIds.contains('dual_station'), isFalse);
      expect(widgetIds.contains('electricity'), isFalse);
    });

    test('Saved layout containing legacy dual_station or electricity automatically filters them out', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dashboardLayoutConfig', '[{"id":"weather_header","isVisible":true},{"id":"dual_station","isVisible":true},{"id":"water_level","isVisible":true}]');

      final settings = SettingsProvider();
      // Allow settings to load
      await Future.delayed(const Duration(milliseconds: 50));
      final widgetIds = settings.dashboardWidgets.map((w) => w.id).toList();

      expect(widgetIds.contains('dual_station'), isFalse);
      expect(widgetIds.contains('electricity'), isFalse);
      expect(widgetIds.contains('weather_header'), isTrue);
      expect(widgetIds.contains('water_level'), isTrue);
    });
  });
}

double _calcDist(double lat1, double lon1, double lat2, double lon2) {
  const double p = 0.017453292519943295;
  final double a = 0.5 -
      math.cos((lat2 - lat1) * p) / 2 +
      math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
  return 12742000 * math.asin(math.sqrt(a));
}
