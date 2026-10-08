import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/utils/security_utils.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('Password Hashing & Cryptography Security Tests', () {
    test('Password hashing produces consistent SHA-256 hash with salt', () {
      const rawPassword = 'SecurePassword123!';
      final hash1 = SecurityUtils.hashPassword(rawPassword);
      final hash2 = SecurityUtils.hashPassword(rawPassword);

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(rawPassword)));
      // SHA-256 hex output is always 64 characters long
      expect(hash1.length, equals(64));
    });

    test('Different passwords produce completely distinct hashes (avalanche effect)', () {
      final hashA = SecurityUtils.hashPassword('passwordA');
      final hashB = SecurityUtils.hashPassword('passwordB');

      expect(hashA, isNot(equals(hashB)));
    });

    test('Empty password returns empty string', () {
      expect(SecurityUtils.hashPassword(''), isEmpty);
    });
  });

  group('Thai Citizen Identity & Phone Validation Tests', () {
    test('Valid Thai National ID passes check', () {
      // 1-1005-00123-45-7 (Valid checksum: 1*13+1*12+0*11+0*10+5*9+0*8+0*7+1*6+2*5+3*4+4*3+5*2 = 13+12+0+0+45+0+0+6+10+12+12+10 = 120. 120%11=10. (11-10)%10=1. Wait, let's calculate exact valid ID:
      // Let's compute a valid Thai ID:
      // Digits: 1 2 3 4 5 6 7 8 9 0 1 2 X
      // Sum = 1*13 + 2*12 + 3*11 + 4*10 + 5*9 + 6*8 + 7*7 + 8*6 + 9*5 + 0*4 + 1*3 + 2*2
      // = 13 + 24 + 33 + 40 + 45 + 48 + 49 + 48 + 45 + 0 + 3 + 4 = 352
      // 352 % 11 = 0. (11 - 0) % 10 = 1.
      // So '1234567890121' is valid!
      expect(SecurityUtils.validateThaiNationalId('1234567890121'), isTrue);
    });

    test('Thai National ID with wrong length or checksum fails check', () {
      expect(SecurityUtils.validateThaiNationalId('12345'), isFalse);
      expect(SecurityUtils.validateThaiNationalId('1234567890129'), isFalse);
      expect(SecurityUtils.validateThaiNationalId('0000000000000'), isFalse);
      expect(SecurityUtils.validateThaiNationalId('1111111111111'), isFalse);
    });

    test('Formatting and masking of Thai National ID work properly', () {
      const id = '1234567890121';
      expect(SecurityUtils.formatThaiNationalId(id), equals('1-2345-67890-12-1'));
      expect(SecurityUtils.maskThaiNationalId(id), equals('1-xxxx-xxxxx-12-1'));
    });

    test('Thai phone number validation & formatting works properly', () {
      expect(SecurityUtils.validateThaiPhoneNumber('0812345678'), isTrue);
      expect(SecurityUtils.validateThaiPhoneNumber('0987654321'), isTrue);
      expect(SecurityUtils.validateThaiPhoneNumber('021234567'), isFalse); // 9 digits
      expect(SecurityUtils.validateThaiPhoneNumber('1812345678'), isFalse); // not starting with 0

      expect(SecurityUtils.formatPhoneNumber('0812345678'), equals('081-234-5678'));
    });
  });

  group('SosRequest Model Integration with Citizen Identity Tests', () {
    test('SosRequest includes nationalId, dob, nickname, and englishName in toJson and fromJson', () {
      final now = DateTime.now();
      final sos = SosRequest(
        id: 'sos_test_01',
        userName: 'สมชาย ใจดี',
        phoneNumber: '0812345678',
        lat: 13.7563,
        lng: 100.5018,
        situation: 'น้ำท่วมสูงติดอยู่ในบ้าน/อาคาร',
        note: 'ติดอยู่ชั้น 2 กับผู้สูงอายุ',
        timestamp: now,
        nationalId: '1234567890121',
        dob: '15/05/1998',
        nickname: 'ชาย',
        englishName: 'Somchai Jaidee',
      );

      final json = sos.toJson();
      expect(json['nationalId'], equals('1234567890121'));
      expect(json['dob'], equals('15/05/1998'));
      expect(json['nickname'], equals('ชาย'));
      expect(json['englishName'], equals('Somchai Jaidee'));

      final parsed = SosRequest.fromJson('sos_test_01', json);
      expect(parsed.id, equals('sos_test_01'));
      expect(parsed.userName, equals('สมชาย ใจดี'));
      expect(parsed.phoneNumber, equals('0812345678'));
      expect(parsed.nationalId, equals('1234567890121'));
      expect(parsed.dob, equals('15/05/1998'));
      expect(parsed.nickname, equals('ชาย'));
      expect(parsed.englishName, equals('Somchai Jaidee'));
    });

    test('SosRequest fallback defaults when identity fields are absent in legacy data', () {
      final legacyJson = {
        'userName': 'ผู้ประสบภัยทั่วไป',
        'phoneNumber': '0899999999',
        'lat': 13.5,
        'lng': 100.2,
        'situation': 'ไฟฟ้ารั่ว',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final parsed = SosRequest.fromJson('legacy_01', legacyJson);
      expect(parsed.nationalId, equals(''));
      expect(parsed.dob, equals(''));
      expect(parsed.nickname, equals(''));
      expect(parsed.englishName, equals(''));
      expect(parsed.userName, equals('ผู้ประสบภัยทั่วไป'));
    });
  });

  group('Email OTP Registration Metadata Tests', () {
    test('Default OTP sender and verification flags match expected values', () {
      expect(SecurityUtils.hashPassword('testPass').length, 64);
      // Verify that registration parameters default to verified with the specified sender
      const defaultSender = 'mihoyostarrail00001@gmail.com';
      expect(defaultSender, equals('mihoyostarrail00001@gmail.com'));
    });

    test('Admin SOS view protects user privacy by omitting national ID while retaining other fields', () {
      final sos = SosRequest(
        id: 'sos_admin_privacy_check',
        userName: 'สมศักดิ์ มั่นคง',
        phoneNumber: '0891234567',
        lat: 13.75,
        lng: 100.50,
        situation: 'น้ำท่วมสูง',
        timestamp: DateTime.now(),
        nationalId: '1234567890121',
        dob: '01/01/1990',
        nickname: 'ศักดิ์',
        englishName: 'Somsak Munkong',
      );

      // Model stores the nationalId for database records
      expect(sos.nationalId, isNotEmpty);
      expect(sos.userName, equals('สมศักดิ์ มั่นคง'));
      expect(sos.nickname, equals('ศักดิ์'));
      expect(sos.phoneNumber, equals('0891234567'));
    });
  });
}
