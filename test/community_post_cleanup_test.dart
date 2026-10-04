import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Community Post and Map Report Marker Synchronization Tests', () {
    test('Map filter excludes hazard markers whose community post was deleted', () {
      final Set<String> activePostKeys = {'post_1', 'post_2'};

      final List<Map<String, dynamic>> reports = [
        {
          'id': 'rep_1',
          'postId': 'post_1',
          'reason': 'น้ำท่วมถนน',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 1000,
        },
        {
          'id': 'rep_2',
          'postId': 'post_deleted_3', // Post has been deleted
          'reason': 'เสาไฟฟ้าเอียง',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 2000,
        },
        {
          'id': 'rep_3',
          'postId': 'post_2',
          'reason': 'ระดับน้ำสูงขึ้น',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 3000,
        },
        {
          'id': 'rep_4',
          'postId': null, // Generic report without post
          'reason': 'แจ้งเหตุทั่วไป',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 4000,
        },
      ];

      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDayMs = 24 * 60 * 60 * 1000;

      final visibleReports = reports.where((report) {
        final timestamp = report['timestamp'] as int? ?? 0;
        if (now - timestamp > oneDayMs) return false;

        final String? postId = report['postId'] as String?;
        if (postId != null && postId.isNotEmpty && !activePostKeys.contains(postId)) {
          return false;
        }
        return true;
      }).toList();

      expect(visibleReports.length, 3);
      expect(visibleReports.any((r) => r['id'] == 'rep_1'), isTrue);
      expect(visibleReports.any((r) => r['id'] == 'rep_2'), isFalse); // Deleted post marker is removed!
      expect(visibleReports.any((r) => r['id'] == 'rep_3'), isTrue);
      expect(visibleReports.any((r) => r['id'] == 'rep_4'), isTrue);
    });

    test('Expired reports (>24h) are filtered out regardless of post state', () {
      final Set<String> activePostKeys = {'post_1'};
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDayMs = 24 * 60 * 60 * 1000;

      final List<Map<String, dynamic>> reports = [
        {
          'id': 'rep_recent',
          'postId': 'post_1',
          'timestamp': now - (2 * 60 * 60 * 1000), // 2 hours ago
        },
        {
          'id': 'rep_expired',
          'postId': 'post_1',
          'timestamp': now - (25 * 60 * 60 * 1000), // 25 hours ago
        },
      ];

      final visibleReports = reports.where((report) {
        final timestamp = report['timestamp'] as int? ?? 0;
        if (now - timestamp > oneDayMs) return false;

        final String? postId = report['postId'] as String?;
        if (postId != null && postId.isNotEmpty && !activePostKeys.contains(postId)) {
          return false;
        }
        return true;
      }).toList();

      expect(visibleReports.length, 1);
      expect(visibleReports.first['id'], 'rep_recent');
    });
  });
}
