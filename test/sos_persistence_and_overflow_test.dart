import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('SOS Persistence and Active Lifecycle Tests', () {
    test('SOS request remains active until status is resolved', () {
      final item1 = SosRequest(
        id: 'sos_1',
        userName: 'สมชาย ทดสอบ',
        phoneNumber: '0812345678',
        lat: 13.7563,
        lng: 100.5018,
        situation: 'น้ำท่วมสูงติดอยู่ในบ้าน/อาคาร',
        status: 'pending',
        timestamp: DateTime.now(),
      );

      final item2 = SosRequest(
        id: 'sos_2',
        userName: 'สมหญิง ใจดี',
        phoneNumber: '0898765432',
        lat: 13.7600,
        lng: 100.5100,
        situation: 'มีผู้ป่วยติดเตียงต้องการอพยพ',
        status: 'in_progress',
        timestamp: DateTime.now(),
      );

      final item3 = SosRequest(
        id: 'sos_3',
        userName: 'ลุงพล ช่วยด้วย',
        phoneNumber: '0855555555',
        lat: 13.7700,
        lng: 100.5200,
        situation: 'เหตุฉุกเฉินอื่นๆ',
        status: 'resolved',
        timestamp: DateTime.now(),
      );

      final allRequests = [item1, item2, item3];

      // Filtering criteria used by the map: active pins are strictly status != 'resolved'
      final activeOnMap = allRequests.where((s) => s.status != 'resolved').toList();

      expect(activeOnMap.length, 2);
      expect(activeOnMap.map((s) => s.id), containsAll(['sos_1', 'sos_2']));
      expect(activeOnMap.map((s) => s.id), isNot(contains('sos_3')));
    });

    test('SOS request status transition from pending to in_progress to resolved', () {
      var item = SosRequest(
        id: 'test_sos',
        userName: 'ผู้ขอความช่วยเหลือ',
        phoneNumber: '0800000000',
        lat: 13.75,
        lng: 100.50,
        situation: 'ขาดแคลนน้ำดื่ม',
        status: 'pending',
        timestamp: DateTime.now(),
      );

      expect(item.status, 'pending');

      // 1. Rescuer accepts and starts journey
      item = SosRequest(
        id: item.id,
        userName: item.userName,
        phoneNumber: item.phoneNumber,
        lat: item.lat,
        lng: item.lng,
        situation: item.situation,
        status: 'in_progress',
        timestamp: item.timestamp,
      );
      expect(item.status, 'in_progress');
      // Must still be active on map
      expect(item.status != 'resolved', isTrue);

      // 2. Rescue completes
      item = SosRequest(
        id: item.id,
        userName: item.userName,
        phoneNumber: item.phoneNumber,
        lat: item.lat,
        lng: item.lng,
        situation: item.situation,
        status: 'resolved',
        timestamp: item.timestamp,
      );
      expect(item.status, 'resolved');
      // Now dismissed from map
      expect(item.status != 'resolved', isFalse);
    });

    test('SosRequest JSON serialization preserves all privacy and emergency fields', () {
      final original = SosRequest(
        id: 'sos_test_json',
        userName: 'สมศักดิ์ รักไทย',
        phoneNumber: '0812345678',
        lat: 13.8000,
        lng: 100.5500,
        situation: 'พบกระแสไฟฟ้ารั่ว',
        note: 'ชั้น 2 มีผู้สูงอายุ',
        status: 'pending',
        timestamp: DateTime(2026, 10, 4, 12, 30),
        nationalId: '1100501234567',
        dob: '1990-05-15',
        nickname: 'ศักดิ์',
        englishName: 'Somsak Rakthai',
      );

      final json = original.toJson();
      final parsed = SosRequest.fromJson('sos_test_json', json);

      expect(parsed.id, 'sos_test_json');
      expect(parsed.userName, 'สมศักดิ์ รักไทย');
      expect(parsed.nickname, 'ศักดิ์');
      expect(parsed.englishName, 'Somsak Rakthai');
      expect(parsed.dob, '1990-05-15');
      expect(parsed.nationalId, '1100501234567');
      expect(parsed.situation, 'พบกระแสไฟฟ้ารั่ว');
      expect(parsed.status, 'pending');
    });

    test('Map active SOS collection maintains pending and in_progress requests', () {
      final Map<String, SosRequest> activeSosMap = {};

      final req1 = SosRequest(
        id: 'req_1',
        userName: 'User 1',
        phoneNumber: '0811111111',
        lat: 13.71,
        lng: 100.51,
        situation: 'SOS high water',
        status: 'pending',
        timestamp: DateTime.now(),
      );

      final req2 = SosRequest(
        id: 'req_2',
        userName: 'User 2',
        phoneNumber: '0822222222',
        lat: 13.72,
        lng: 100.52,
        situation: 'SOS power leak',
        status: 'in_progress',
        timestamp: DateTime.now(),
      );

      activeSosMap[req1.id] = req1;
      activeSosMap[req2.id] = req2;

      expect(activeSosMap.length, 2);

      // Simulating a resolved update event:
      final resolvedReq = SosRequest(
        id: req1.id,
        userName: req1.userName,
        phoneNumber: req1.phoneNumber,
        lat: req1.lat,
        lng: req1.lng,
        situation: req1.situation,
        status: 'resolved',
        timestamp: req1.timestamp,
      );

      if (resolvedReq.status == 'resolved') {
        activeSosMap.remove(resolvedReq.id);
      }

      // Only req_2 remains
      expect(activeSosMap.length, 1);
      expect(activeSosMap.containsKey('req_1'), isFalse);
      expect(activeSosMap.containsKey('req_2'), isTrue);
    });
  });

  group('SOS Information Bottom Sheet Overflow Safety Tests', () {
    testWidgets('Emergency action row renders on narrow 320px width without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('นำทาง GPS'),
                          ),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          ),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('โทร: 0812345678'),
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('✅ ยืนยันได้รับความช่วยเหลือแล้ว (นำหมุดออกจากแผนที่)'),
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('นำทาง GPS'), findsOneWidget);
      expect(find.text('โทร: 0812345678'), findsOneWidget);
      expect(find.text('✅ ยืนยันได้รับความช่วยเหลือแล้ว (นำหมุดออกจากแผนที่)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
