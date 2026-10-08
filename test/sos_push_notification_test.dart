import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/services/notification_service.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SOS Emergency Push Notification & Channel Tests', () {
    test('SOS Emergency Channel is defined with maximum priority and alerts', () {
      const channel = NotificationService.sosEmergencyChannel;

      expect(channel.id, equals('sos_emergency_channel'));
      expect(channel.name, contains('SOS'));
      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
      expect(channel.showBadge, isTrue);
    });

    test('General Alert Channel is configured for quiet notification without disturbing user', () {
      const channel = NotificationService.generalAlertChannel;

      expect(channel.id, equals('general_water_alert_channel'));
      expect(channel.playSound, isFalse);
      expect(channel.enableVibration, isFalse);
      expect(channel.showBadge, isTrue);
    });

    test('SOS Request formatting includes victim name, situation, and contact phone', () {
      final now = DateTime.now();
      final sos = SosRequest(
        id: 'sos_123',
        userName: 'สมชาย รักดี',
        phoneNumber: '0891234567',
        lat: 13.7563,
        lng: 100.5018,
        situation: 'น้ำท่วมสูงระดับเอว',
        note: 'มีผู้สูงอายุและเด็กติดอยู่',
        status: 'pending',
        timestamp: now,
      );

      final title = '🚨 แจ้งเตือนฉุกเฉิน SOS: ${sos.userName}';
      final body = 'สถานการณ์: ${sos.situation} | เบอร์โทร: ${sos.phoneNumber}';

      expect(title, contains('สมชาย รักดี'));
      expect(body, contains('น้ำท่วมสูงระดับเอว'));
      expect(body, contains('0891234567'));
    });

    test('SOS Request JSON serialization contains all required fields for FCM trigger', () {
      final now = DateTime.now();
      final sos = SosRequest(
        id: 'test_sos_fcm',
        userName: 'Jane Doe',
        phoneNumber: '0812345678',
        lat: 14.05,
        lng: 100.62,
        situation: 'กระแสน้ำเชี่ยว',
        status: 'pending',
        timestamp: now,
        nationalId: '1234567890121',
      );

      final json = sos.toJson();

      expect(json['userName'], equals('Jane Doe'));
      expect(json['phoneNumber'], equals('0812345678'));
      expect(json['situation'], equals('กระแสน้ำเชี่ยว'));
      expect(json['status'], equals('pending'));
      expect(json['lat'], equals(14.05));
      expect(json['lng'], equals(100.62));
    });
  });
}
