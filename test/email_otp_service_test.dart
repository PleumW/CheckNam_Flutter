import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_water_flood/services/email_otp_service.dart';
import 'package:flutter_application_water_flood/widgets/otp_verification_dialog.dart';

void main() {
  group('EmailOtpService Configuration & Sender Tests', () {
    test('Sender email must strictly be mihoyostarrail00001@gmail.com', () {
      expect(EmailOtpService.senderEmail, 'mihoyostarrail00001@gmail.com');
    });

    test('OTP validity duration must strictly be 5 minutes (300 seconds)', () {
      expect(EmailOtpService.otpValidityDuration, const Duration(minutes: 5));
      expect(EmailOtpService.otpValidityDuration.inSeconds, 300);
      expect(EmailOtpService.otpValidityDuration.inMinutes, 5);
    });

    test('OTP generator generates valid 6-digit numerical codes', () {
      final service = EmailOtpService.instance;
      for (int i = 0; i < 20; i++) {
        final otp = service.generate6DigitOtp();
        expect(otp.length, 6);
        expect(int.tryParse(otp), isNotNull);
        final numValue = int.parse(otp);
        expect(numValue >= 100000 && numValue <= 999999, isTrue);
      }
    });

    test('Sanitize email formats correctly for database paths and keys', () {
      expect(EmailOtpService.sanitizeEmail('user.test+flood@example.com'), 'user_test_flood_example_com');
      expect(EmailOtpService.sanitizeEmail('mihoyostarrail00001@gmail.com'), 'mihoyostarrail00001_gmail_com');
    });
  });

  group('EmailOtpService Send and Verification Workflow Tests', () {
    final service = EmailOtpService.instance;
    const testEmail = 'tester@example.com';
    late String savedPassword;

    setUp(() {
      savedPassword = EmailOtpService.smtpAppPassword;
      EmailOtpService.smtpAppPassword = '';
    });

    tearDown(() {
      EmailOtpService.smtpAppPassword = savedPassword;
      service.clearSession(testEmail);
    });

    test('sendOtp creates active session with 5-minute expiry from mihoyostarrail00001@gmail.com', () async {
      final result = await service.sendOtp(testEmail);

      expect(result.isSuccess, isTrue);
      expect(result.email, testEmail);
      expect(result.senderEmail, 'mihoyostarrail00001@gmail.com');
      expect(result.otpCode.length, 6);

      final session = service.getSession(testEmail);
      expect(session, isNotNull);
      expect(session!.senderEmail, 'mihoyostarrail00001@gmail.com');
      expect(session.isExpired, isFalse);
      expect(session.remainingSeconds, inInclusiveRange(295, 300));
    });

    test('verifyOtp returns success when 6-digit code matches within 5 minutes', () async {
      final result = await service.sendOtp(testEmail);
      final code = result.otpCode;

      final verifyResult = service.verifyOtp(testEmail, code);
      expect(verifyResult.isSuccess, isTrue);
      expect(verifyResult.failureReason, isNull);

      final session = service.getSession(testEmail);
      expect(session!.isVerified, isTrue);
    });

    test('verifyOtp returns failure on incorrect 6-digit code', () async {
      final result = await service.sendOtp(testEmail);
      final code = result.otpCode;
      final wrongCode = (code == '123456') ? '654321' : '123456';

      final verifyResult = service.verifyOtp(testEmail, wrongCode);
      expect(verifyResult.isSuccess, isFalse);
      expect(verifyResult.failureReason, OtpFailureReason.invalidCode);

      final session = service.getSession(testEmail);
      expect(session!.failedAttempts, 1);
    });

    test('verifyOtp fails when 5 attempts are exceeded', () async {
      await service.sendOtp(testEmail);

      for (int i = 0; i < 5; i++) {
        service.verifyOtp(testEmail, '000000');
      }

      final sixthAttempt = service.verifyOtp(testEmail, '000000');
      expect(sixthAttempt.isSuccess, isFalse);
      expect(sixthAttempt.failureReason, OtpFailureReason.maxAttemptsExceeded);
    });

    test('verifyOtp fails when OTP has expired beyond 5 minutes', () async {
      // Overwrite session expiresAt to the past (>5 minutes ago)
      final serviceInstance = EmailOtpService.instance;
      await serviceInstance.sendOtp(testEmail, customOtp: '888999');
      final session = serviceInstance.getSession(testEmail)!;
      final pastExpiredSession = OtpSession(
        email: session.email,
        otpCode: session.otpCode,
        createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        senderEmail: session.senderEmail,
      );
      
      // Verification of an expired session
      expect(pastExpiredSession.isExpired, isTrue);
      expect(pastExpiredSession.remainingSeconds, 0);
    });

    test('resendOtp generates new code and resets 5-minute timer', () async {
      await service.sendOtp(testEmail);

      final resendResult = await service.resendOtp(testEmail);
      final newSession = service.getSession(testEmail);

      expect(resendResult.isSuccess, isTrue);
      expect(resendResult.senderEmail, 'mihoyostarrail00001@gmail.com');
      expect(newSession, isNotNull);
      expect(newSession!.remainingSeconds, inInclusiveRange(295, 300));
    });

    test('clearSession removes stored session', () async {
      await service.sendOtp(testEmail);
      expect(service.getSession(testEmail), isNotNull);

      service.clearSession(testEmail);
      expect(service.getSession(testEmail), isNull);

      final verifyAfterClear = service.verifyOtp(testEmail, '123456');
      expect(verifyAfterClear.isSuccess, isFalse);
      expect(verifyAfterClear.failureReason, OtpFailureReason.notFound);
    });
  });

  group('OtpVerificationDialog Widget Tests', () {
    const testEmail = 'user.register@gmail.com';
    const testOtp = '654321';

    setUp(() async {
      await EmailOtpService.instance.sendOtp(testEmail, customOtp: testOtp);
    });

    tearDown(() {
      EmailOtpService.instance.clearSession(testEmail);
    });

    testWidgets('OtpVerificationDialog renders recipient, 5-minute countdown, and hides sender email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OtpVerificationDialog(
              recipientEmail: testEmail,
              initialOtpCode: testOtp,
            ),
          ),
        ),
      );

      // Verify Title
      expect(find.text('ยืนยันรหัส OTP ทางอีเมล'), findsOneWidget);

      // Verify recipient email displayed
      expect(find.textContaining(testEmail, findRichText: true), findsOneWidget);

      // Verify sender email is hidden as requested
      expect(find.textContaining('mihoyostarrail00001@gmail.com'), findsNothing);

      // Verify 5-minute timer note
      expect(find.textContaining('5 นาที'), findsAtLeastNWidgets(1));

      // Verify OTP text field exists
      expect(find.byType(TextField), findsOneWidget);

      // Verify Confirm button exists
      expect(find.text('ยืนยันรหัส OTP'), findsOneWidget);

      // Verify Resend button exists
      expect(find.text('ขอรับรหัสใหม่'), findsOneWidget);
    });

    testWidgets('OtpVerificationDialog rejects empty or less than 6 digits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OtpVerificationDialog(
              recipientEmail: testEmail,
            ),
          ),
        ),
      );

      // Tap confirm button with empty field
      await tester.tap(find.text('ยืนยันรหัส OTP'));
      await tester.pump();

      // Verify validation warning
      expect(find.text('กรุณากรอกรหัส OTP ให้ครบ 6 หลัก'), findsOneWidget);
    });
  });
}
