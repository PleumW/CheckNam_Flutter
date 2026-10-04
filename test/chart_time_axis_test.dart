import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chart Time Axis Non-Repeating Logic Tests', () {
    test('24h history generates unique, sequential, non-repeating time labels', () {
      final now = DateTime.now();
      // Generate 25 points spanning 24 hours
      final List<Map<String, dynamic>> h24 = [];
      for (int i = 24; i >= 0; i--) {
        h24.add({
          'timestamp': now.subtract(Duration(hours: i)).millisecondsSinceEpoch,
          'waterLevel': 30.0 + (i % 5),
        });
      }

      final int totalTicks = 4;
      final List<String> labels = [];

      for (int t = 0; t <= totalTicks; t++) {
        final int idx = (t * (h24.length - 1) / totalTicks).round().clamp(0, h24.length - 1);
        final item = h24[idx];
        final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
        final firstDt = DateTime.fromMillisecondsSinceEpoch(h24.first['timestamp']);
        final lastDt = DateTime.fromMillisecondsSinceEpoch(h24.last['timestamp']);
        final bool isShortDuration = lastDt.difference(firstDt).inHours.abs() < 12;

        String label;
        if (isShortDuration) {
          label = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          if (t == totalTicks) {
            label = 'วันนี้ ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } else if (dt.day != now.day) {
            label = 'วาน ${dt.hour.toString().padLeft(2, '0')}:00';
          } else {
            label = '${dt.hour.toString().padLeft(2, '0')}:00';
          }
        }
        labels.add(label);
      }

      expect(labels.length, 5);
      // Verify no duplicates
      final uniqueSet = labels.toSet();
      expect(uniqueSet.length, labels.length, reason: 'All 24h labels must be unique: $labels');
      expect(labels.last.contains('วันนี้'), isTrue);
      expect(labels.first.contains('วาน'), isTrue);
    });

    test('7-day history generates unique, non-repeating labels with day name and date', () {
      final now = DateTime.now();
      // Generate 43 points spanning 7 days (168 hours)
      final List<Map<String, dynamic>> h7d = [];
      for (int i = 42; i >= 0; i--) {
        h7d.add({
          'timestamp': now.subtract(Duration(hours: i * 4)).millisecondsSinceEpoch,
          'waterLevel': 25.0,
        });
      }

      final int totalTicks = 6;
      final List<String> labels = [];

      for (int t = 0; t <= totalTicks; t++) {
        final int idx = (t * (h7d.length - 1) / totalTicks).round().clamp(0, h7d.length - 1);
        final item = h7d[idx];
        final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
        String label;
        if (t == totalTicks || (dt.day == now.day && dt.month == now.month)) {
          label = 'วันนี้';
        } else {
          const dayNames = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
          final dayName = dayNames[(dt.weekday - 1) % 7];
          label = '$dayName ${dt.day}';
        }
        labels.add(label);
      }

      expect(labels.length, 7);
      // Verify no duplicates
      final uniqueSet = labels.toSet();
      expect(uniqueSet.length, labels.length, reason: 'All 7d labels must be unique: $labels');
      expect(labels.last, 'วันนี้');
    });

    test('Live history generates unique countdown seconds labels', () {
      final int totalTicks = 4;
      final List<String> labels = [];

      for (int t = 0; t <= totalTicks; t++) {
        String label;
        if (t == totalTicks) {
          label = 'ล่าสุด';
        } else {
          final int secsAgo = (totalTicks - t) * 5;
          label = '-${secsAgo}s';
        }
        labels.add(label);
      }

      expect(labels, ['-20s', '-15s', '-10s', '-5s', 'ล่าสุด']);
      expect(labels.toSet().length, 5);
    });
  });
}
