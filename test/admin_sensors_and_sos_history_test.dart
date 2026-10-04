import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('Admin Management Sensors and SOS History Tests', () {
    test('DeviceData hasWaterLevelSensor reflects in dynamicModules properly', () {
      final deviceInstalled = DeviceData(
        id: 'dev_1',
        name: 'สถานีทดสอบ 1',
        lat: 13.75,
        lng: 100.50,
        hasWaterLevelSensor: true,
        waterLevel: 25.0,
        lastSeen: DateTime.now(),
      );

      final modulesInstalled = deviceInstalled.dynamicModules;
      expect(modulesInstalled['ultrasonic']!['installed'], isTrue);
      expect(modulesInstalled['ultrasonic']!['status'], equals('OK'));
      expect(modulesInstalled['ultrasonic']!['message'], contains('25.0 ซม.'));

      final deviceNotInstalled = DeviceData(
        id: 'dev_2',
        name: 'สถานีทดสอบ 2',
        lat: 13.75,
        lng: 100.50,
        hasWaterLevelSensor: false,
        waterLevel: 0.0,
        lastSeen: DateTime.now(),
      );

      final modulesNotInstalled = deviceNotInstalled.dynamicModules;
      expect(modulesNotInstalled['ultrasonic']!['installed'], isFalse);
      expect(modulesNotInstalled['ultrasonic']!['status'], equals('NOT_INSTALLED'));
      expect(modulesNotInstalled['ultrasonic']!['message'], equals('ยังไม่ได้ติดตั้งเซนเซอร์วัดระดับน้ำ'));
    });

    test('SOS History filters by selected date correctly', () {
      final targetDate = DateTime(2026, 10, 2);
      final otherDate = DateTime(2026, 10, 1);

      final List<SosRequest> list = [
        SosRequest(
          id: 'sos_1',
          userName: 'สมชาย',
          phoneNumber: '0812345678',
          situation: 'น้ำท่วมสูง',
          note: 'ติดอยู่ในบ้าน',
          lat: 13.75,
          lng: 100.50,
          timestamp: DateTime(2026, 10, 2, 14, 30),
        ),
        SosRequest(
          id: 'sos_2',
          userName: 'สมหญิง',
          phoneNumber: '0898765432',
          situation: 'ไฟฟ้ารั่ว',
          note: 'ระดับน้ำแตะเสาไฟ',
          lat: 13.76,
          lng: 100.51,
          timestamp: DateTime(2026, 10, 2, 9, 15),
        ),
        SosRequest(
          id: 'sos_3',
          userName: 'มานะ',
          phoneNumber: '0855555555',
          situation: 'น้ำท่วมสูง',
          note: 'ขอความช่วยเหลือด่วน',
          lat: 13.77,
          lng: 100.52,
          timestamp: DateTime(2026, 10, 1, 18, 00),
        ),
      ];

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;

      final filteredTarget = list.where((s) => isSameDay(s.timestamp, targetDate)).toList();
      expect(filteredTarget.length, equals(2));
      expect(filteredTarget.map((s) => s.id), containsAll(['sos_1', 'sos_2']));

      final filteredOther = list.where((s) => isSameDay(s.timestamp, otherDate)).toList();
      expect(filteredOther.length, equals(1));
      expect(filteredOther.first.id, equals('sos_3'));

      // If no date selected (all)
      const DateTime? filterDate = null;
      final all = list.where((s) => filterDate == null || isSameDay(s.timestamp, filterDate)).toList();
      expect(all.length, equals(3));
    });

    test('Google Maps navigation URL generates correct destination coordinates', () {
      const double lat = 13.756331;
      const double lng = 100.501765;
      final Uri appUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      final Uri webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

      expect(appUrl.scheme, equals('google.navigation'));
      expect(appUrl.path, contains('$lat,$lng'));
      expect(webUrl.host, equals('www.google.com'));
      expect(webUrl.queryParameters['destination'], equals('$lat,$lng'));
    });

    test('SosRequest.fromJson parses robustly with alternative keys and timestamp formats', () {
      final json1 = {
        'userName': 'นายทดสอบ',
        'phoneNumber': '0811111111',
        'lat': '13.75',
        'lng': '100.50',
        'situation': 'น้ำเข้าบ้าน',
        'note': 'ต้องการเรือ',
        'status': 'pending',
        'timestamp': 1727878000000,
      };
      final req1 = SosRequest.fromJson('id_1', json1);
      expect(req1.userName, equals('นายทดสอบ'));
      expect(req1.phoneNumber, equals('0811111111'));
      expect(req1.lat, equals(13.75));
      expect(req1.lng, equals(100.50));
      expect(req1.timestamp.millisecondsSinceEpoch, equals(1727878000000));

      // Test with alternative keys and string timestamp
      final json2 = {
        'name': 'สมหญิง',
        'phone': '0899999999',
        'lat': 13.80,
        'lng': 100.55,
        'title': 'ขอความช่วยเหลือ',
        'description': 'ผู้ป่วยติดเตียง',
        'timestamp': '1727878000000',
      };
      final req2 = SosRequest.fromJson('id_2', json2);
      expect(req2.userName, equals('สมหญิง'));
      expect(req2.phoneNumber, equals('0899999999'));
      expect(req2.situation, equals('ขอความช่วยเหลือ'));
      expect(req2.note, equals('ผู้ป่วยติดเตียง'));
      expect(req2.timestamp.millisecondsSinceEpoch, equals(1727878000000));

      // Test with empty/null fields default values
      final json3 = <String, dynamic>{};
      final req3 = SosRequest.fromJson('id_3', json3);
      expect(req3.userName, equals('ผู้ประสบภัย'));
      expect(req3.phoneNumber, equals('-'));
      expect(req3.situation, equals('ขอความช่วยเหลือด่วน'));
      expect(req3.status, equals('pending'));
      expect(req3.lat, equals(0.0));
      expect(req3.lng, equals(0.0));
    });

    test('24/7 device history data timestamps filter within 24 hours and 7 days appropriately', () {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      final twelveHoursAgo = now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch;
      final threeDaysAgo = now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      final tenDaysAgo = now.subtract(const Duration(days: 10)).millisecondsSinceEpoch;

      final historyMap = {
        'pt_1': {
          'timestamp': oneHourAgo,
          'waterLevel': 22.5,
          'rainfall': 0.0,
          'waterFlow': 5.0,
          'isReal': true,
        },
        'pt_2': {
          'timestamp': twelveHoursAgo,
          'waterLevel': 25.0,
          'rainfall': 10.0,
          'waterFlow': 8.0,
          'isReal': true,
        },
        'pt_3': {
          'timestamp': threeDaysAgo,
          'waterLevel': 30.0,
          'rainfall': 15.0,
          'waterFlow': 12.0,
          'isReal': true,
        },
        'pt_4': {
          'timestamp': tenDaysAgo,
          'waterLevel': 18.0,
          'rainfall': 0.0,
          'waterFlow': 3.0,
          'isReal': true,
        },
      };

      final oneDayMs = 24 * 60 * 60 * 1000;
      final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      final nowMs = now.millisecondsSinceEpoch;

      final pts24h = historyMap.values
          .where((v) => nowMs - (v['timestamp'] as int) <= oneDayMs)
          .toList();
      final pts7d = historyMap.values
          .where((v) => nowMs - (v['timestamp'] as int) <= sevenDaysMs)
          .toList();

      expect(pts24h.length, equals(2));
      expect(pts7d.length, equals(3));
    });
  });
}
