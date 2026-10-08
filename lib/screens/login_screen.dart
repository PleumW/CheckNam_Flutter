import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/auth_provider.dart';
import '../services/email_otp_service.dart';
import '../widgets/otp_verification_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Citizen Real Identity Fields (ข้อมูลจริงสำหรับการกู้ภัยและระบุตัวตน)
  final _nationalIdController = TextEditingController();
  final _dobController = TextEditingController();
  final _firstNameThController = TextEditingController();
  final _lastNameThController = TextEditingController();
  final _nicknameThController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPdpaAccepted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    _dobController.dispose();
    _firstNameThController.dispose();
    _lastNameThController.dispose();
    _nicknameThController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() async {
    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน')),
      );
      return;
    }

    if (!_isLogin) {
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร')),
        );
        return;
      }
      if (password != _confirmPasswordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รหัสผ่านทั้งสองช่องไม่ตรงกัน')),
        );
        return;
      }

      final nationalId = _nationalIdController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (nationalId.length != 13) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกเลขประจำตัวประชาชนให้ครบ 13 หลัก')),
        );
        return;
      }

      if (_dateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือก วัน เดือน ปีเกิด (ค.ศ.)')),
        );
        return;
      }

      final firstNameTh = _firstNameThController.text.trim();
      final lastNameTh = _lastNameThController.text.trim();
      final nicknameTh = _nicknameThController.text.trim();
      if (firstNameTh.isEmpty || lastNameTh.isEmpty || nicknameTh.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกชื่อจริง นามสกุล และชื่อเล่น ให้ครบถ้วน')),
        );
        return;
      }

      final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (phone.length != 10 || !phone.startsWith('0')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกเบอร์โทรศัพท์มือถือ 10 หลักให้ถูกต้อง (เช่น 0812345678)')),
        );
        return;
      }

      if (!_isPdpaAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('กรุณาติ๊กยืนยันการคุ้มครองข้อมูลส่วนบุคคล (PDPA) ก่อนดำเนินการ'),
          ),
        );
        return;
      }

      // ส่งรหัส OTP ไปยังอีเมลผู้ใช้งานก่อนสร้างบัญชี (ส่งจาก mihoyostarrail00001@gmail.com, มีเวลา 5 นาที)
      setState(() => _isLoading = true);
      OtpSendResult otpSendResult;
      try {
        otpSendResult = await EmailOtpService.instance.sendOtp(email);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ส่งรหัส OTP ไม่สำเร็จ: $e')),
          );
        }
        return;
      }

      if (mounted) setState(() => _isLoading = false);

      // เปิดหน้าต่างกรอกรหัส OTP (นับถอยหลัง 5 นาที)
      if (!mounted) return;
      final bool? isVerified = await OtpVerificationDialog.show(
        context: context,
        recipientEmail: email,
        initialOtpCode: otpSendResult.otpCode,
      );

      // หากผู้ใช้กดยกเลิกหรือไม่ผ่านการยืนยัน OTP ให้หยุดการสมัคร
      if (isVerified != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('การลงทะเบียนถูกยกเลิก เนื่องจากยังไม่ได้ยืนยันรหัส OTP'),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await authProvider.signIn(email, password);
      } else {
        await authProvider.register(
          email: email,
          password: password,
          nationalId: _nationalIdController.text.trim().replaceAll(RegExp(r'\D'), ''),
          dob: _dobController.text.trim(),
          firstNameTh: _firstNameThController.text.trim(),
          lastNameTh: _lastNameThController.text.trim(),
          nicknameTh: _nicknameThController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          isPdpaAccepted: _isPdpaAccepted,
          isEmailOtpVerified: true,
        );

        EmailOtpService.instance.clearSession(email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              content: Text('ลงทะเบียนและยืนยันตัวตนผ่านรหัส OTP สำเร็จ ยินดีต้อนรับ!'),
            ),
          );
        }
      }
    } catch (e) {
      String msg = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
      final err = e.toString().toLowerCase();
      if (err.contains('user-not-found') || err.contains('invalid-credential') || err.contains('wrong-password')) {
        msg = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      } else if (err.contains('email-already-in-use')) {
        msg = 'อีเมลนี้ถูกใช้งานในระบบแล้ว';
      } else if (err.contains('weak-password')) {
        msg = 'รหัสผ่านคาดเดาง่ายเกินไป กรุณาใช้อย่างน้อย 6 ตัวอักษร';
      } else {
        msg = 'เกิดข้อผิดพลาด: ${e.toString()}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark theme
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInDown(
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.water_drop, size: 70, color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeInDown(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    _isLogin ? 'ยินดีต้อนรับกลับมา' : 'ลงทะเบียนยืนยันตัวตน',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                FadeInDown(
                  delay: const Duration(milliseconds: 250),
                  child: Text(
                    _isLogin
                        ? 'ระบบเฝ้าระวังน้ำท่วมและไฟฟ้ารั่วอัจฉริยะ'
                        : 'กรอกข้อมูลจริงเพื่อใช้ในการยืนยันตัวตนและการช่วยเหลือฉุกเฉิน (SOS)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 28),

                // -----------------------------
                // SECTION: บัญชีและรหัสผ่าน (Account)
                // -----------------------------
                if (!_isLogin) ...[
                  _buildSectionHeader(
                    icon: Icons.lock_person_rounded,
                    title: 'ข้อมูลบัญชีผู้ใช้',
                  ),
                  const SizedBox(height: 8),
                ],

                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'อีเมล (Email) *',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                FadeInUp(
                  delay: const Duration(milliseconds: 350),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'รหัสผ่าน (Password) *',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),

                if (!_isLogin) ...[
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 380),
                    child: TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ยืนยันรหัสผ่าน (Confirm Password) *',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -----------------------------
                  // SECTION: ข้อมูลจริงระบุตัวตน (Citizen Identity)
                  // -----------------------------
                  _buildSectionHeader(
                    icon: Icons.badge_outlined,
                    title: 'ข้อมูลจริงยืนยันตัวตน',
                  ),
                  const SizedBox(height: 8),

                  // เลขบัตรประชาชน 13 หลัก
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: TextField(
                      controller: _nationalIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'เลขบัตรประจำตัวประชาชน (13 หลัก) *',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.credit_card_rounded, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // วันเดือนปีเกิด (ค.ศ.)
                  FadeInUp(
                    delay: const Duration(milliseconds: 420),
                    child: TextField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000, 1, 1),
                          firstDate: DateTime(1920),
                          lastDate: DateTime.now(),
                          helpText: 'เลือกวันเดือนปีเกิด (ค.ศ.)',
                        );
                        if (date != null) {
                          setState(() {
                            _dateOfBirth = date;
                            _dobController.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} (ค.ศ.)";
                          });
                        }
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'วัน เดือน ปีเกิด (ค.ศ. เช่น 15/05/1998) *',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: Colors.grey),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ชื่อจริง - นามสกุล
                  FadeInUp(
                    delay: const Duration(milliseconds: 440),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameThController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'ชื่อจริง *',
                              hintStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lastNameThController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'นามสกุล *',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ชื่อเล่น
                  FadeInUp(
                    delay: const Duration(milliseconds: 460),
                    child: TextField(
                      controller: _nicknameThController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ชื่อเล่น *',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.tag_faces_rounded, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // เบอร์โทรศัพท์มือถือ
                  FadeInUp(
                    delay: const Duration(milliseconds: 480),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'เบอร์โทรศัพท์มือถือ (10 หลัก) *',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        helperText: 'ใช้สำหรับโทรติดต่อและประสานงานกู้ภัยฉุกเฉิน (SOS)',
                        helperStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // -----------------------------
                  // SECTION: นโยบายคุ้มครองข้อมูลส่วนบุคคล (PDPA)
                  // -----------------------------
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isPdpaAccepted ? Colors.green.withValues(alpha: 0.5) : Colors.blueAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isPdpaAccepted ? Icons.verified_user_rounded : Icons.shield_outlined,
                                color: _isPdpaAccepted ? Colors.green : Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'นโยบายคุ้มครองข้อมูลส่วนบุคคล (PDPA Privacy Policy)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ระบบจะเก็บรักษาข้อมูลของท่านเป็นความลับตามมาตรฐานความปลอดภัย ข้อมูลจริงที่ลงทะเบียน (เลขบัตร ปชช, วันเดือนปีเกิด, ชื่อจริง-นามสกุล, ชื่อเล่น, เบอร์โทรศัพท์) จะถูกนำไปใช้เพื่อการอ้างอิงยืนยันตัวตนและการช่วยเหลือกู้ภัยยามฉุกเฉิน (SOS) เท่านั้น โดยระบบมีนโยบายเข้มงวดว่าจะไม่มีการนำข้อมูลไปเผยแพร่หรือรั่วไหลสู่ภายนอกโดยเด็ดขาด',
                            style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              setState(() => _isPdpaAccepted = !_isPdpaAccepted);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isPdpaAccepted,
                                  activeColor: Colors.green,
                                  checkColor: Colors.white,
                                  onChanged: (val) {
                                    setState(() => _isPdpaAccepted = val ?? false);
                                  },
                                ),
                                const Expanded(
                                  child: Text(
                                    'ข้าพเจ้ายืนยันว่าเป็นข้อมูลจริง และยินยอมตามข้อตกลงนี้',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Submit Button
                FadeInUp(
                  delay: const Duration(milliseconds: 540),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isLogin ? 'เข้าสู่ระบบ' : 'ยืนยันและสมัครสมาชิก',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 580),
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'ยังไม่มีบัญชีใช่หรือไม่? สมัครสมาชิก' : 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                FadeInUp(
                  delay: const Duration(milliseconds: 620),
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final auth = context.read<AuthProvider>();
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isLoading = true);
                            try {
                              await auth.signInAsGuest();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.blue.withValues(alpha: 0.7)),
                    ),
                    child: const Text('เข้าสู่ระบบในฐานะผู้เยี่ยมชม (Guest)', style: TextStyle(fontSize: 15, color: Colors.blueAccent)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ),
      ],
    );
  }
}
