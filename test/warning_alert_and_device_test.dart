import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';
import 'package:flutter_application_water_flood/screens/alert_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('Mockup device test and device_1 Tests', () {
    test('SensorProvider initializes device_1 and device_test side by side', () {
      final sensor = SensorProvider();
      final devices = sensor.devices;

      // 1. Verify device_1 exists
      expect(devices.containsKey('device_1'), isTrue);
      final dev1 = devices['device_1']!;
      expect(dev1.id, anyOf(equals('device_1'), equals('station_upstream')));
      expect(dev1.name, contains('device_1'));
      expect(dev1.lat, equals(13.7563));
      expect(dev1.lng, equals(100.5018));

      // 2. Verify device_test exists right next to device_1 (~110 meters away)
      expect(devices.containsKey('device_test'), isTrue);
      final devTest = devices['device_test']!;
      expect(devTest.id, equals('device_test'));
      expect(devTest.name, contains('device test'));
      expect(devTest.lat, equals(13.7568));
      expect(devTest.lng, equals(100.5028));
      expect(devTest.isUpstream, isTrue);
      expect(devTest.isDeviceOnline, isTrue);
    });

    test('device_test can be simulated with custom water levels', () {
      final sensor = SensorProvider();
      sensor.simulateDataFromIoT(
        deviceId: 'device_test',
        lat: 13.7568,
        lng: 100.5028,
        waterLevel: 20.0,
        waterFlow: 8.0,
        rainfall: 15.0,
        isOnline: true,
      );

      final devTest = sensor.devices['device_test']!;
      expect(devTest.waterLevel, equals(20.0));
      expect(devTest.isFloodWarning, isTrue);
      expect(devTest.isFloodDanger, isFalse);

      // 35 cm is Danger (Critical 30-49.9 cm)
      sensor.simulateDataFromIoT(
        deviceId: 'device_test',
        lat: 13.7568,
        lng: 100.5028,
        waterLevel: 35.0,
        waterFlow: 8.0,
        rainfall: 15.0,
        isOnline: true,
      );
      expect(devTest.waterLevel, equals(35.0));
      expect(devTest.isFloodDanger, isTrue);
      expect(devTest.isFloodWarning, isFalse);
    });

    test('SensorProvider deletes device, decrements count from 10 to 9, persists deletion, and can restore', () async {
      SharedPreferences.setMockInitialValues({});
      final sensor = SensorProvider();
      expect(sensor.devices.length, equals(10));
      expect(sensor.uniqueDeviceList.length, equals(10));
      expect(sensor.devices.containsKey('station_rangsit'), isTrue);

      // 1. Delete station_rangsit
      await sensor.deleteDevice('station_rangsit');
      expect(sensor.devices.containsKey('station_rangsit'), isFalse);
      expect(sensor.devices.length, equals(9));
      expect(sensor.uniqueDeviceList.length, equals(9));
      expect(sensor.deletedDeviceIds.contains('station_rangsit'), isTrue);

      // Verify persisted in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedDeleted = prefs.getStringList('deleted_device_ids');
      expect(savedDeleted, contains('station_rangsit'));

      // 2. Simulate app restart by creating a new SensorProvider instance
      final sensorAfterRestart = SensorProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(sensorAfterRestart.devices.containsKey('station_rangsit'), isFalse);
      expect(sensorAfterRestart.uniqueDeviceList.length, equals(9));

      // 3. Restore all devices
      await sensorAfterRestart.restoreAllDevices();
      expect(sensorAfterRestart.devices.containsKey('station_rangsit'), isTrue);
      expect(sensorAfterRestart.devices.length, equals(10));
      expect(sensorAfterRestart.uniqueDeviceList.length, equals(10));
      expect(sensorAfterRestart.deletedDeviceIds, isEmpty);
    });
  });

  group('Warning Alert Notice Screen Tests', () {
    testWidgets('AlertScreen renders warning notice with action guidelines card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlertScreen(
            title: 'เฝ้าระวัง! ระดับน้ำเริ่มสูงขึ้นเข้าเกณฑ์เตือนภัย',
            waterLevel: '35',
            type: 'warning',
          ),
        ),
      );

      // Verify category subtitle
      expect(find.text('แจ้งเตือนระดับน้ำเฝ้าระวัง'), findsOneWidget);

      // Verify main title
      expect(find.text('เฝ้าระวัง! ระดับน้ำเริ่มสูงขึ้นเข้าเกณฑ์เตือนภัย'), findsOneWidget);

      // Verify water level and badge
      expect(find.text('35'), findsOneWidget);
      expect(find.text('เฝ้าระวัง'), findsOneWidget);

      // Verify action guidelines card header
      expect(find.textContaining('วิธีการรับมือและข้อควรปฏิบัติ'), findsOneWidget);

      // Verify action guideline items
      expect(find.textContaining('ยกของมีค่าขึ้นที่สูง'), findsOneWidget);
      expect(find.textContaining('เตรียมยานพาหนะ'), findsOneWidget);
      expect(find.textContaining('สำรองพลังงาน'), findsOneWidget);
      expect(find.textContaining('ติดตามสถานการณ์'), findsOneWidget);

      // Verify buttons (map and guide buttons removed per requirement)
      expect(find.text('ดูคู่มือการปฏิบัติตัวเมื่อเกิดภัย'), findsNothing);
      expect(find.text('ดูแผนที่จุดเสี่ยงและระดับน้ำ'), findsNothing);
      expect(find.textContaining('1784'), findsOneWidget);
    });

    testWidgets('AlertScreen renders critical flood notice with critical guidelines and 191', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlertScreen(
            title: 'อันตราย! ระดับน้ำสูงเกินกำหนด',
            waterLevel: '75',
            type: 'flood',
          ),
        ),
      );

      expect(find.text('แจ้งเตือนระดับน้ำวิกฤต'), findsOneWidget);
      expect(find.text('อันตราย! ระดับน้ำสูงเกินกำหนด'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('วิกฤต'), findsOneWidget);
      expect(find.textContaining('ตัดสะพานไฟทันที'), findsOneWidget);
      expect(find.textContaining('อพยพไปยังที่ปลอดภัย'), findsOneWidget);
      expect(find.text('โทรสายด่วนขอความช่วยเหลือ (191)'), findsOneWidget);
    });
  });
}
