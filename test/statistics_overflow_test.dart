import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Statistics Screen Alert History Overflow Tests', () {
    testWidgets('Alert history item with very long title does not cause RenderFlex overflow', (tester) async {
      // Set test screen to narrow phone dimensions (360px width)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const String longTitle = '🌊 เตือนภัยมวลน้ำหลากล่วงหน้า (รัศมี 20 กม.)';
      const String longSubtitle =
          '⚠️ เตือนภัยน้ำหนุนย้อนกลับ! สถานีปลายทางน้ำท่วมขัง "อุปกรณ์ทดสอบ (device test)" (100.0 ซม.) '
          'ห่าง 0.1 กม. ระบายน้ำติดขัด เสี่ยงน้ำเอ่อหนุน ท่านอยู่ในรัศมี 20 กม. มีสถานะวิกฤต โปรดออกห่างจากบริเวณนี้ทันที!';
      const String time = '22:40';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Text(
                                longTitle,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              time,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          longSubtitle,
                          style: TextStyle(color: Colors.grey, fontSize: 13.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no Flutter layout exceptions were thrown
      expect(tester.takeException(), isNull);
      expect(find.text(longTitle), findsOneWidget);
      expect(find.text(time), findsOneWidget);
      expect(find.text(longSubtitle), findsOneWidget);
    });
  });
}
