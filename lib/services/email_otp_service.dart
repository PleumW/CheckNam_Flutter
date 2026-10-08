import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_database/firebase_database.dart';

/// ผลลัพธ์จากการตรวจสอบ OTP
enum OtpFailureReason { notFound, expired, invalidCode, maxAttemptsExceeded }

class OtpVerifyResult {
  final bool isSuccess;
  final String message;
  final OtpFailureReason? failureReason;

  const OtpVerifyResult.success([this.message = 'ยืนยันรหัส OTP สำเร็จ'])
    : isSuccess = true,
      failureReason = null;

  const OtpVerifyResult.failure(this.message, this.failureReason)
    : isSuccess = false;

  @override
  String toString() =>
      'OtpVerifyResult(isSuccess: $isSuccess, message: $message, reason: $failureReason)';
}

/// ผลลัพธ์จากการส่งรหัส OTP
class OtpSendResult {
  final bool isSuccess;
  final String email;
  final String otpCode;
  final String message;
  final bool isSentViaSmtp;
  final String senderEmail;
  final DateTime expiresAt;

  const OtpSendResult({
    required this.isSuccess,
    required this.email,
    required this.otpCode,
    required this.message,
    required this.isSentViaSmtp,
    required this.senderEmail,
    required this.expiresAt,
  });
}

/// เซสชันของรหัส OTP ที่ถูกสร้างขึ้น
class OtpSession {
  final String email;
  final String otpCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String senderEmail;
  int failedAttempts;
  bool isVerified;

  OtpSession({
    required this.email,
    required this.otpCode,
    required this.createdAt,
    required this.expiresAt,
    required this.senderEmail,
    this.failedAttempts = 0,
    this.isVerified = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingSeconds =>
      max(0, expiresAt.difference(DateTime.now()).inSeconds);
}

/// บริการจัดการส่งและยืนยันรหัส OTP ทางอีเมล
/// กำหนดผู้ส่ง: mihoyostarrail00001@gmail.com
/// กำหนดอายุการใช้งาน: 5 นาที (300 วินาที)
class EmailOtpService {
  static final EmailOtpService _instance = EmailOtpService._internal();
  factory EmailOtpService() => _instance;
  static EmailOtpService get instance => _instance;

  EmailOtpService._internal();

  /// อีเมลต้นทางสำหรับส่งรหัส OTP
  static const String senderEmail = 'mihoyostarrail00001@gmail.com';
  static const String senderDisplayName = 'Water Flood GIS System';

  /// ระยะเวลาหมดอายุของรหัส OTP: 5 นาที
  static const Duration otpValidityDuration = Duration(minutes: 5);
  static const int maxAllowedAttempts = 5;

  /// รหัสผ่านสำหรับ Gmail SMTP (Google App Password 16 ตัวอักษร)
  /// สามารถตั้งค่าผ่าน static variable นี้ หรือบันทึกไว้ใน Firebase Realtime Database path `system_config/smtp_app_password`
  static String smtpAppPassword = 'aduj erxw bvrm pdoj';

  String? _smtpAppPassword;

  /// จัดเก็บเซสชัน OTP ในหน่วยความจำ (Key: sanitized email)
  final Map<String, OtpSession> _sessions = {};

  /// Firebase Database Reference สำหรับซิงค์สถานะ OTP (ถ้าเปิดใช้งาน)
  DatabaseReference? _dbRef;

  void setSmtpAppPassword(String? appPassword) {
    _smtpAppPassword = appPassword;
  }

  void setDatabaseReference(DatabaseReference? ref) {
    _dbRef = ref;
  }

  DatabaseReference? get _database {
    if (_dbRef != null) return _dbRef;
    try {
      _dbRef = FirebaseDatabase.instance.ref();
      return _dbRef;
    } catch (_) {
      return null;
    }
  }

  /// ปรับอีเมลเป็นคีย์ที่ปลอดภัยสำหรับจัดเก็บ
  static String sanitizeEmail(String email) {
    return email.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  /// สุ่มรหัสตัวเลข 6 หลัก (100000 - 999999)
  String generate6DigitOtp() {
    final random = Random.secure();
    final code = 100000 + random.nextInt(900000);
    return code.toString();
  }

  /// ดึงข้อมูลเซสชันปัจจุบันสำหรับอีเมล
  OtpSession? getSession(String email) {
    return _sessions[sanitizeEmail(email)];
  }

  /// สร้างและส่งรหัส OTP ไปยังอีเมลปลายทาง
  /// มีระยะเวลาให้กรอกคือ 5 นาที และส่งจาก mihoyostarrail00001@gmail.com
  Future<OtpSendResult> sendOtp(
    String recipientEmail, {
    String? customOtp,
  }) async {
    final cleanEmail = recipientEmail.trim().toLowerCase();
    final key = sanitizeEmail(cleanEmail);
    final now = DateTime.now();
    final expiresAt = now.add(otpValidityDuration);
    final otpCode = customOtp ?? generate6DigitOtp();

    final session = OtpSession(
      email: cleanEmail,
      otpCode: otpCode,
      createdAt: now,
      expiresAt: expiresAt,
      senderEmail: senderEmail,
    );

    _sessions[key] = session;

    // บันทึก/ซิงค์ไปยัง Firebase Realtime Database เพื่อความปลอดภัย (ถ้ามี)
    final db = _database;
    if (db != null) {
      try {
        await db.child('email_otps/$key').set({
          'email': cleanEmail,
          'otpCode': otpCode,
          'senderEmail': senderEmail,
          'createdAt': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'validityMinutes': 5,
          'isVerified': false,
        });
      } catch (e) {
        debugPrint('[EmailOtpService] Firebase sync notice: $e');
      }
    }

    bool sentViaSmtp = false;
    String statusMessage = '';

    // พยายามส่งผ่าน SMTP หากมีการตั้งค่ารหัสผ่านแอพ (App Password)
    String? appPass =
        _smtpAppPassword ??
        (smtpAppPassword.isNotEmpty ? smtpAppPassword : null);
    if ((appPass == null || appPass.isEmpty) && db != null) {
      try {
        final snap = await db.child('system_config/smtp_app_password').get();
        if (snap.exists &&
            snap.value != null &&
            snap.value.toString().trim().isNotEmpty) {
          appPass = snap.value.toString().trim();
          _smtpAppPassword = appPass;
        }
      } catch (_) {}
    }

    if (appPass != null && appPass.isNotEmpty) {
      try {
        final smtpServer = gmail(senderEmail, appPass);
        final message = Message()
          ..from = const Address(senderEmail, senderDisplayName)
          ..recipients.add(cleanEmail)
          ..subject =
              '[$otpCode] รหัสยืนยัน OTP สำหรับสมัครสมาชิก Water Flood GIS (มีอายุ 5 นาที)'
          ..text = _buildPlainTextBody(otpCode)
          ..html = _buildHtmlBody(otpCode);

        await send(message, smtpServer, timeout: const Duration(seconds: 15));
        sentViaSmtp = true;
        statusMessage = 'ส่งรหัส OTP ไปยัง $cleanEmail เรียบร้อยแล้ว';
      } catch (e) {
        debugPrint('[EmailOtpService] SMTP send error: $e');
        statusMessage = 'ส่งผ่านเครือข่ายจำลอง (SMTP ขัดข้อง: $e)';
      }
    } else {
      statusMessage = 'สร้างรหัส OTP เรียบร้อยแล้ว (มีอายุ 5 นาที)';
    }

    return OtpSendResult(
      isSuccess: true,
      email: cleanEmail,
      otpCode: otpCode,
      message: statusMessage,
      isSentViaSmtp: sentViaSmtp,
      senderEmail: senderEmail,
      expiresAt: expiresAt,
    );
  }

  /// ตรวจสอบความถูกต้องของรหัส OTP
  OtpVerifyResult verifyOtp(String recipientEmail, String inputCode) {
    final cleanEmail = recipientEmail.trim().toLowerCase();
    final key = sanitizeEmail(cleanEmail);
    final session = _sessions[key];

    if (session == null) {
      return const OtpVerifyResult.failure(
        'ไม่พบข้อมูลรหัส OTP สำหรับอีเมลนี้ กรุณากดขอรับรหัสใหม่',
        OtpFailureReason.notFound,
      );
    }

    // ตรวจสอบจำนวนครั้งที่กรอกผิดเกินกำหนด
    if (session.failedAttempts >= maxAllowedAttempts) {
      return const OtpVerifyResult.failure(
        'คุณกรอกรหัสผิดเกินจำนวนครั้งที่กำหนด (5 ครั้ง) กรุณากดส่งรหัสใหม่',
        OtpFailureReason.maxAttemptsExceeded,
      );
    }

    // ตรวจสอบเวลาหมดอายุ (5 นาที)
    if (session.isExpired) {
      return const OtpVerifyResult.failure(
        'รหัส OTP หมดอายุแล้ว (เกิน 5 นาที) กรุณากดส่งรหัสใหม่',
        OtpFailureReason.expired,
      );
    }

    // ตรวจสอบความถูกต้องของรหัส 6 หลัก
    final trimmedInput = inputCode.trim();
    if (session.otpCode != trimmedInput) {
      session.failedAttempts++;
      final remaining = maxAllowedAttempts - session.failedAttempts;
      return OtpVerifyResult.failure(
        'รหัส OTP ไม่ถูกต้อง (เหลือโอกาสกรอกอีก $remaining ครั้ง)',
        OtpFailureReason.invalidCode,
      );
    }

    // ผ่านการยืนยันสำเร็จ
    session.isVerified = true;

    // อัปเดตไปยัง Firebase Realtime Database
    try {
      _database?.child('email_otps/$key/isVerified').set(true);
      _database
          ?.child('email_otps/$key/verifiedAt')
          .set(DateTime.now().toIso8601String());
    } catch (_) {}

    return const OtpVerifyResult.success('ยืนยันรหัส OTP สำเร็จ');
  }

  /// ส่งรหัส OTP ใหม่อีกครั้ง (Resend)
  Future<OtpSendResult> resendOtp(String recipientEmail) async {
    return sendOtp(recipientEmail);
  }

  /// ล้างเซสชัน OTP เมื่อลงทะเบียนเสร็จสมบูรณ์
  void clearSession(String recipientEmail) {
    final key = sanitizeEmail(recipientEmail);
    _sessions.remove(key);
    try {
      _database?.child('email_otps/$key').remove();
    } catch (_) {}
  }

  /// สร้างเนื้อหาอีเมลแบบข้อความธรรมดา (Plain Text)
  String _buildPlainTextBody(String otpCode) {
    return '''
[ระบบเฝ้าระวังน้ำท่วมและไฟฟ้ารั่วอัจฉริยะ (Water Flood GIS)]
รหัสยืนยัน OTP สำหรับการสมัครสมาชิกของคุณคือ: $otpCode

- ระยะเวลาใช้งาน: 5 นาที นับจากเวลาที่ได้รับอีเมล

กรุณานำรหัส 6 หลักนี้ไปกรอกในแอปพลิเคชันเพื่อยืนยันตัวตน
หากท่านไม่ได้เป็นผู้ทำรายการ กรุณาละเว้นอีเมลฉบับนี้
''';
  }

  /// สร้างเนื้อหาอีเมลแบบ HTML ที่สวยงามตามธีม Dark
  String _buildHtmlBody(String otpCode) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>รหัสยืนยัน OTP</title>
</head>
<body style="margin: 0; padding: 20px; background-color: #0F172A; font-family: 'Sarabun', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0">
    <tr>
      <td align="center">
        <table width="100%" max-width="520" style="max-width: 520px; background-color: #1E293B; border-radius: 16px; border: 1px solid #334155; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #0284C7, #0369A1); padding: 28px 24px; text-align: center;">
              <h1 style="margin: 0; color: #FFFFFF; font-size: 22px; font-weight: bold;">ระบบเฝ้าระวังน้ำท่วม Water Flood GIS</h1>
              <p style="margin: 6px 0 0 0; color: #E0F2FE; font-size: 13px;">ยืนยันความถูกต้องของอีเมลเพื่อเปิดใช้งานบัญชี</p>
            </td>
          </tr>
          
          <!-- Content Body -->
          <tr>
            <td style="padding: 28px 24px;">
              <p style="margin: 0 0 16px 0; color: #94A3B8; font-size: 14px; line-height: 1.6;">
                สวัสดีครับ,<br>
                ระบบได้รับคำขอลงทะเบียนบัญชีใหม่ของคุณแล้ว โปรดใช้รหัส OTP 6 หลักด้านล่างนี้เพื่อยืนยันตัวตน:
              </p>
              
              <!-- OTP Box -->
              <div style="background-color: #0F172A; border: 2px dashed #38BDF8; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
                <div style="font-size: 12px; color: #94A3B8; letter-spacing: 1.5px; text-transform: uppercase;">รหัส OTP ยืนยันตัวตน</div>
                <div style="font-size: 38px; font-weight: 800; letter-spacing: 10px; color: #38BDF8; margin: 12px 0;">$otpCode</div>
                <div style="display: inline-block; background-color: rgba(245, 158, 11, 0.15); border: 1px solid rgba(245, 158, 11, 0.4); border-radius: 20px; padding: 4px 14px; font-size: 12px; color: #FBBF24; font-weight: 600;">
                  ⏱️ มีเวลาให้ลงคือ 5 นาที
                </div>
              </div>

              <!-- Notice Details -->
              <div style="background-color: #172554; border-left: 4px solid #38BDF8; padding: 12px 16px; border-radius: 4px; margin-bottom: 20px;">
                <p style="margin: 0; font-size: 12px; color: #BAE6FD; line-height: 1.5;">
                  <b>ระยะเวลาหมดอายุ:</b> ภายใน 5 นาทีนับจากได้รับอีเมลฉบับนี้
                </p>
              </div>

              <p style="margin: 0; color: #64748B; font-size: 12px; line-height: 1.5;">
                หากคุณไม่ได้ส่งคำขอลงทะเบียน กรุณาเพิกเฉยต่อข้อความนี้ ข้อมูลบัญชีของคุณจะไม่ถูกเปิดใช้งานจนกว่าจะยืนยันรหัสเสร็จสิ้น
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #0F172A; padding: 16px 24px; text-align: center; border-top: 1px solid #334155;">
              <p style="margin: 0; color: #475569; font-size: 11px;">
                © 2026 Water Flood GIS & Early Warning System. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// ส่งอีเมลแจ้งเตือนเหตุฉุกเฉิน SOS ไปยัง Admin ทันทีผ่าน Gmail SMTP
  Future<bool> sendUrgentSosEmailToAdmin({
    required String adminEmail,
    required String victimName,
    required String situation,
    required String phone,
    String? note,
    String? coordinates,
  }) async {
    final password = _smtpAppPassword ?? smtpAppPassword;
    if (password.isEmpty) {
      debugPrint(
        '[EmailOtpService] SMTP password not configured, skipping urgent SOS email.',
      );
      return false;
    }

    try {
      final smtpServer = gmail(senderEmail, password);
      final title =
          '🚨 [SOS ฉุกเฉิน] ผู้ประสบภัย $victimName ร้องขอความช่วยเหลือ!';
      final plainText =
          '''
[ระบบแจ้งเตือนเหตุฉุกเฉิน SOS - Water Flood GIS]
มีผู้ประสบภัยร้องขอความช่วยเหลือด่วน!

ผู้ประสบภัย: $victimName
สถานการณ์: $situation
เบอร์ติดต่อ: $phone
${note != null && note.isNotEmpty ? 'หมายเหตุ: $note\n' : ''}${coordinates != null && coordinates.isNotEmpty ? 'พิกัด GPS: $coordinates\n' : ''}
เวลาที่แจ้ง: ${DateTime.now().toLocal()}

กรุณาตรวจสอบในระบบจัดการของ Admin หรือเปิดแอปพลิเคชันเพื่อเข้าช่วยเหลือผู้ประสบภัยโดยด่วน
''';

      final message = Message()
        ..from = const Address(senderEmail, senderDisplayName)
        ..recipients.add(adminEmail.trim())
        ..subject = title
        ..text = plainText;

      await send(message, smtpServer);
      debugPrint(
        '[EmailOtpService] Successfully sent urgent SOS email to admin: $adminEmail',
      );
      return true;
    } catch (e) {
      debugPrint(
        '[EmailOtpService] Error sending urgent SOS email to admin: $e',
      );
      return false;
    }
  }
}
