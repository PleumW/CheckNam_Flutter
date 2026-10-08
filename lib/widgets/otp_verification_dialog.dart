import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/email_otp_service.dart';

/// ไดอะล็อกสำหรับกรอกและยืนยันรหัส OTP ทางอีเมล
/// กำหนดเวลาสำหรับกรอกรหัสคือ 5 นาที (300 วินาที)
/// แสดงอีเมลต้นทาง: mihoyostarrail00001@gmail.com
class OtpVerificationDialog extends StatefulWidget {
  final String recipientEmail;
  final String? initialOtpCode; // สำหรับโหมดทดสอบหรือแสดงคำแนะนำ

  const OtpVerificationDialog({
    super.key,
    required this.recipientEmail,
    this.initialOtpCode,
  });

  /// แสดงไดอะล็อกยืนยัน OTP และคืนค่า true เมื่อยืนยันสำเร็จ
  static Future<bool?> show({
    required BuildContext context,
    required String recipientEmail,
    String? initialOtpCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OtpVerificationDialog(
        recipientEmail: recipientEmail,
        initialOtpCode: initialOtpCode,
      ),
    );
  }

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _countdownTimer;
  int _remainingSeconds = 300; // 5 นาที = 300 วินาที
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _currentOtpHint;

  @override
  void initState() {
    super.initState();
    _currentOtpHint = widget.initialOtpCode;
    _syncTimerWithSession();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncTimerWithSession() {
    final session = EmailOtpService.instance.getSession(widget.recipientEmail);
    if (session != null) {
      _remainingSeconds = session.remainingSeconds;
      _currentOtpHint = session.otpCode;
    } else {
      _remainingSeconds = 300;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          _errorMessage = 'รหัส OTP หมดอายุแล้ว (เกิน 5 นาที) กรุณากดส่งรหัสใหม่';
        }
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'กรุณากรอกรหัส OTP ให้ครบ 6 หลัก';
      });
      return;
    }

    if (_remainingSeconds <= 0) {
      setState(() {
        _errorMessage = 'รหัส OTP หมดอายุแล้ว (เกิน 5 นาที) กรุณากดส่งรหัสใหม่';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = EmailOtpService.instance.verifyOtp(widget.recipientEmail, code);

    setState(() {
      _isVerifying = false;
    });

    if (result.isSuccess) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final result = await EmailOtpService.instance.resendOtp(widget.recipientEmail);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      _remainingSeconds = 300; // รีเซ็ตเวลากลับเป็น 5 นาที
      _otpController.clear();
      _currentOtpHint = result.otpCode;
    });

    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF0369A1),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ส่งรหัส OTP ใหม่แล้ว (หมดอายุใน 5 นาที)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remainingSeconds <= 0;
    final timerColor = isExpired
        ? Colors.redAccent
        : (_remainingSeconds <= 60 ? Colors.amberAccent : Colors.cyanAccent);

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Icon & Close Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, color: Colors.lightBlueAccent, size: 22),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              const Text(
                'ยืนยันรหัส OTP ทางอีเมล',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),

              // Recipient description
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  children: [
                    const TextSpan(text: 'ระบบได้ส่งรหัส OTP 6 หลักไปยัง\n'),
                    TextSpan(
                      text: widget.recipientEmail,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Countdown Timer Badge (5 นาที)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: timerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: timerColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                      color: timerColor,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isExpired
                            ? 'รหัส OTP หมดอายุแล้ว (เกิน 5 นาที)'
                            : 'เวลาที่เหลือสำหรับกรอกรหัส: ${_formatDuration(_remainingSeconds)} (จำกัด 5 นาที)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // OTP 6-Digit Input Field
              TextField(
                controller: _otpController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                    color: Colors.white24,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
                onSubmitted: (_) => _handleVerify(),
              ),

              // Quick fill helper for convenience / testing mode
              if (_currentOtpHint != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    _otpController.text = _currentOtpHint!;
                    _handleVerify();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'แตะเพื่อกรอกรหัส $_currentOtpHint อัตโนมัติ',
                            style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Verify Button
              ElevatedButton(
                onPressed: (_isVerifying || isExpired) ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  disabledBackgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'ยืนยันรหัส OTP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),

              const SizedBox(height: 8),

              // Resend Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ยังไม่ได้รับรหัส? ',
                    style: TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                  TextButton(
                    onPressed: _isResending ? null : _handleResend,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.lightBlueAccent),
                          )
                        : const Text(
                            'ขอรับรหัสใหม่',
                            style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
