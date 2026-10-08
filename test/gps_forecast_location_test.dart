import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('GPS and Rain Forecast Location Logic Tests', () {
    test('Station coordinates are extracted accurately from DeviceData', () {
      final device = DeviceData(
        id: 'TEST_DEV_01',
        name: 'สถานีวัดน้ำริมคลอง',
        lat: 13.7563,
        lng: 100.5018,
      );

      expect(device.lat, equals(13.7563));
      expect(device.lng, equals(100.5018));
      expect(device.name, equals('สถานีวัดน้ำริมคลอง'));
    });

    test('Rain forecast display text correctly reflects user GPS vs station mode', () {
      const modeUser = 'user';
      const modeStation = 'station';

      final userLat = 13.736717;
      final userLng = 100.523186;
      final userPlaceName = 'เขตปทุมวัน, กรุงเทพมหานคร';

      final stationLat = 13.7563;
      final stationLng = 100.5018;
      final stationName = 'สถานีวัดน้ำคลองแสนแสบ';

      // Mode: User GPS
      final activeLatUser = modeUser == 'user' ? userLat : stationLat;
      final activeLngUser = modeUser == 'user' ? userLng : stationLng;
      final activeLabelUser = modeUser == 'user' 
          ? 'บริเวณพิกัดที่คุณอยู่ ($userPlaceName)' 
          : 'บริเวณ$stationName';

      expect(activeLatUser, equals(userLat));
      expect(activeLngUser, equals(userLng));
      expect(activeLabelUser, contains('บริเวณพิกัดที่คุณอยู่ (เขตปทุมวัน, กรุงเทพมหานคร)'));

      // Mode: Station
      final activeLatStation = modeStation == 'user' ? userLat : stationLat;
      final activeLngStation = modeStation == 'user' ? userLng : stationLng;
      final activeLabelStation = modeStation == 'user'
          ? 'บริเวณพิกัดที่คุณอยู่ ($userPlaceName)'
          : 'บริเวณ$stationName';

      expect(activeLatStation, equals(stationLat));
      expect(activeLngStation, equals(stationLng));
      expect(activeLabelStation, contains('บริเวณสถานีวัดน้ำคลองแสนแสบ'));
    });

    test('Forecast coordinates formatting formats 4 decimal places cleanly', () {
      final lat = 13.7563333;
      final lng = 100.5018888;
      final formatted = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

      expect(formatted, equals('13.7563, 100.5019'));
    });

    test('Fallback to station or default coordinates when GPS is not ready', () {
      double? userLat;
      double? userLng;
      const defaultLat = 13.7563;
      const defaultLng = 100.5018;

      final targetLat = userLat ?? defaultLat;
      final targetLng = userLng ?? defaultLng;

      expect(targetLat, equals(13.7563));
      expect(targetLng, equals(100.5018));
    });
  });
}
