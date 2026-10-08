import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../utils/security_utils.dart';

class SosEmergencyModal extends StatefulWidget {
  const SosEmergencyModal({super.key});

  static Future<void> show(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.isGuest || auth.role == 'guest') {
      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('จำกัดสิทธิ์การใช้งาน'),
          content: const Text('ผู้เยี่ยมชมไม่สามารถส่งสัญญาณขอความช่วยเหลือ SOS ได้ กรุณาเข้าสู่ระบบเพื่อใช้งานฟังก์ชันนี้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ไว้คราวหลัง', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
              child: const Text('เข้าสู่ระบบ'),
            ),
          ],
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SosEmergencyModal(),
    );
  }

  @override
  State<SosEmergencyModal> createState() => _SosEmergencyModalState();
}

class _SosEmergencyModalState extends State<SosEmergencyModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedSituation = 'น้ำท่วมสูงติดอยู่ในบ้าน/อาคาร';
  bool _isSubmitting = false;

  final List<String> _situations = [
    'น้ำท่วมสูงติดอยู่ในบ้าน/อาคาร',
    'พบกระแสไฟฟ้ารั่ว / เสาไฟจมน้ำ',
    'มีผู้ป่วยติดเตียง / คนชราต้องการอพยพ',
    'ขาดแคลนอาหารและน้ำดื่มสะอาด',
    'ต้องการเรือช่วยอพยพด่วน',
    'เหตุฉุกเฉินอื่นๆ',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        if (auth.fullIdentityText.isNotEmpty) {
          _nameController.text = auth.fullIdentityText;
        } else if (auth.user!.displayName != null && auth.user!.displayName!.isNotEmpty) {
          _nameController.text = auth.user!.displayName!;
        } else {
          _nameController.text = auth.user!.email?.split('@').first ?? '';
        }

        if (auth.phoneNumber.isNotEmpty) {
          _phoneController.text = auth.phoneNumber;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _submitSos(double lat, double lng) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final sensor = context.read<SensorProvider>();
      final auth = context.read<AuthProvider>();
      String name = _nameController.text.trim();
      if (name.isEmpty) {
        if (auth.fullIdentityText.isNotEmpty) {
          name = auth.fullIdentityText;
        } else if (auth.user != null) {
          name = auth.user!.displayName ?? auth.user!.email?.split('@').first ?? 'ผู้ประสบภัย';
        } else {
          name = 'ผู้ประสบภัย';
        }
      }
      final phone = _phoneController.text.trim();
      final note = _noteController.text.trim();

      await sensor.sendSosRequest(
        userName: name,
        phoneNumber: phone,
        lat: lat,
        lng: lng,
        situation: _selectedSituation,
        note: note,
        nationalId: auth.nationalId,
        dob: auth.dob,
        nickname: auth.nicknameTh,
        englishName: auth.fullEnglishName,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ส่งสัญญาณขอความช่วยเหลือ SOS เรียบร้อยแล้ว!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งข้อมูล: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _shareLocation(double lat, double lng) {
    final auth = context.read<AuthProvider>();
    final name = _nameController.text.trim().isEmpty ? 'ผู้ประสบภัย' : _nameController.text.trim();
    String text = '🚨 [ขอความช่วยเหลือฉุกเฉิน SOS]\nผู้แจ้ง: $name';
    if (auth.fullEnglishName.isNotEmpty) {
      text += ' (${auth.fullEnglishName})';
    }
    text += '\nเบอร์ติดต่อ: ${_phoneController.text.trim()}';
    if (auth.nationalId.isNotEmpty) {
      text += '\nเลขบัตร ปชช: ${SecurityUtils.maskThaiNationalId(auth.nationalId)}';
    }
    if (auth.dob.isNotEmpty) {
      text += '\nวันเกิด (ค.ศ.): ${auth.dob}';
    }
    text += '\nสถานการณ์: $_selectedSituation\nพิกัด GPS: https://maps.google.com/?q=$lat,$lng\nรายละเอียด: ${_noteController.text.trim()}';

    SharePlus.instance.share(ShareParams(text: text, subject: 'สัญญาณขอความช่วยเหลือ SOS'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final location = context.watch<LocationProvider>();
    final auth = context.watch<AuthProvider>();
    final double lat = location.currentPosition?.latitude ?? 13.7563;
    final double lng = location.currentPosition?.longitude ?? 100.5018;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Title Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sos_rounded, color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ส่งสัญญาณขอความช่วยเหลือฉุกเฉิน (SOS)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          Text(
                            'พิกัดจะถูกส่งไปยังระบบส่วนกลางและเจ้าหน้าที่กู้ภัยทันที',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Citizen Verified Badge Card
                if (auth.nationalId.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ข้อมูลยืนยันตัวตน: ${auth.fullIdentityText}${auth.fullEnglishName.isNotEmpty ? ' (${auth.fullEnglishName})' : ''}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green),
                                softWrap: true,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'เลขบัตร ปชช: ${SecurityUtils.maskThaiNationalId(auth.nationalId)} | วันเกิด: ${auth.dob}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Location Chip Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('พิกัด GPS ปัจจุบันของคุณ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_location_rounded, color: Colors.blueAccent, size: 20),
                        tooltip: 'แชร์พิกัด',
                        onPressed: () => _shareLocation(lat, lng),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Speed Dial Row
                const Text(
                  '📞 โทรสายด่วนฉุกเฉินทันที:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickCallButton('1784', 'ปภ. สายด่วน', Colors.orange.shade800),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickCallButton('1669', 'กู้ชีพ/ฉุกเฉิน', Colors.red.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickCallButton('199', 'ดับเพลิง-กู้ภัย', Colors.blue.shade800),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Situation Selector
                const Text(
                  'ประเภทเหตุฉุกเฉิน:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _situations.map((sit) {
                    final isSelected = _selectedSituation == sit;
                    return ChoiceChip(
                      label: Text(
                        sit,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.redAccent,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSituation = sit);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Contact Name & Phone
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อผู้ติดต่อ / ผู้ประสบภัย',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'กรุณาระบุเบอร์โทรศัพท์ติดต่อ';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'เบอร์โทรศัพท์ติดต่อ *',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'จุดสังเกต / ข้อมูลเพิ่มเติม (เช่น ชั้น 2, มีคนแก่ 1 คน)',
                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Big Action Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.redAccent.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.emergency_share_rounded, size: 22),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isSubmitting ? 'กำลังส่งข้อมูล...' : '🚨 ส่งสัญญาณขอความช่วยเหลือ SOS',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : () => _submitSos(lat, lng),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildQuickCallButton(String number, String label, Color color) {
    return InkWell(
      onTap: () => _makeCall(number),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_forwarded_rounded, color: color, size: 16),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                number,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
