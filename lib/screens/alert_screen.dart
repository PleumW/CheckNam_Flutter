import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sensor_provider.dart';
import '../services/audio_alarm_service.dart';

class AlertScreen extends StatelessWidget {
  final String? title;
  final String? waterLevel;
  final String? type; // 'leakage', 'flood', or 'warning'
  final String? subtitle;

  const AlertScreen({
    super.key,
    this.title,
    this.waterLevel,
    this.type = 'flood',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Support route arguments override if provided
    final args = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic>? argMap;
    if (args is Map<String, dynamic>) {
      argMap = args;
    }

    final String effectiveType = argMap?['type']?.toString() ?? type ?? 'flood';
    final bool isWarning = effectiveType == 'warning';
    final bool isLeakage = effectiveType == 'leakage';

    final Color dangerColor = (isWarning || isLeakage)
        ? const Color(0xFFF59E0B) // Amber
        : const Color(0xFFEF4444); // Crimson Red

    final double parsedLevel = double.tryParse(argMap?['waterLevel']?.toString() ?? waterLevel ?? '0.0') ?? 0.0;

    final String effectiveTitle = argMap?['title']?.toString() ??
        title ??
        (isWarning
            ? 'สถานะ : เฝ้าระวัง'
            : (isLeakage
                ? 'สถานะ : ระวังกระแสไฟฟ้ารั่ว'
                : (parsedLevel >= 50.0 ? 'สถานะ : วิกฤตสูงสุด' : 'สถานะ : วิกฤต')));

    SensorProvider? sensor;
    try {
      sensor = Provider.of<SensorProvider?>(context, listen: false);
    } catch (_) {
      sensor = null;
    }
    final currentDev = sensor?.currentDevice;

    final String effectiveWaterLevel = argMap?['waterLevel']?.toString() ??
        waterLevel ??
        (currentDev != null ? currentDev.waterLevel.toStringAsFixed(1) : (isWarning ? '25' : '55'));

    final String effectiveSubtitle = argMap?['subtitle']?.toString() ??
        subtitle ??
        (isWarning
            ? 'แจ้งเตือนระดับน้ำเฝ้าระวัง'
            : (isLeakage
                ? 'แจ้งเตือนอันตรายไฟฟ้ารั่ว'
                : 'แจ้งเตือนระดับน้ำวิกฤต'));

    final String badgeText = isWarning
        ? 'เฝ้าระวัง'
        : (isLeakage ? 'รั่วไหล' : 'วิกฤต');

    final String hardwareText = parsedLevel >= 50.0
        ? '🔴 ไฟแดงติด • 🔊 ไซเรนดังกระหึ่ม!'
        : (parsedLevel >= 30.0
            ? '🔴 ไฟแดงติด • 🔇 Buzzer เงียบ'
            : (parsedLevel >= 10.0
                ? '🟠 ไฟเหลืองติด • 🔇 Buzzer เงียบ'
                : '🟢 ไฟเขียวติด • 🔇 Buzzer เงียบ'));

    final String trafficText = parsedLevel >= 50.0
        ? 'รถเล็กและรถเก๋งเครื่องดับ 100% ห้ามสัญจรผ่านเด็ดขาด'
        : (parsedLevel >= 30.0
            ? 'รถเก๋งเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด'
            : (parsedLevel >= 10.0
                ? 'รถเก๋งสัญจรลำบาก มอเตอร์ไซค์เสี่ยงเครื่องดับ'
                : 'รถทุกชนิดสัญจรผ่านได้สะดวก'));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Modern dark slate backdrop
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            onPressed: () {
              AudioAlarmService().mute();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: AudioAlarmService(),
            builder: (context, _) {
              final alarm = AudioAlarmService();
              final bool isPlaying = alarm.isPlaying;
              return Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8, right: 16, left: 4),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? Colors.redAccent.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying ? Colors.redAccent : Colors.white24,
                    width: isPlaying ? 1.5 : 1.0,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: isPlaying ? Colors.redAccent : Colors.white70,
                    size: 20,
                  ),
                  tooltip: isPlaying ? 'ปิดเสียงไซเรน' : 'เปิดเสียงไซเรน',
                  onPressed: () {
                    if (isPlaying) {
                      alarm.mute();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔇 ปิดเสียงไซเรนชั่วคราวแล้ว'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.black87,
                        ),
                      );
                    } else {
                      alarm.resetMute();
                      alarm.startSiren();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔊 เปิดเสียงไซเรนแล้ว'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Glowing Hazard Icon Container
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: dangerColor.withValues(alpha: 0.35), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: dangerColor.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 8,
                    )
                  ],
                ),
                child: Icon(
                  isLeakage
                      ? Icons.bolt_rounded
                      : (isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.crisis_alert_rounded),
                  size: 68,
                  color: dangerColor,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                effectiveSubtitle,
                style: TextStyle(
                  color: dangerColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                effectiveTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Water Level & Hardware/Traffic Details Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop_rounded, color: dangerColor, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ระดับน้ำปัจจุบัน',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  effectiveWaterLevel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('ซม.',
                                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: dangerColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      color: dangerColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ระยะจากเซนเซอร์ (ติดสูง 100 ซม.):', style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5)),
                        Text('${(100.0 - parsedLevel).clamp(0.0, 100.0).toStringAsFixed(1)} ซม.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ฮาร์ดแวร์ตัวเครื่อง:', style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5)),
                        Text(hardwareText, style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'การสัญจร: $trafficText',
                        style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Guidelines Card (วิธีการรับมือและข้อควรปฏิบัติ)
              _buildActionGuidelinesCard(
                isWarning: isWarning,
                isLeakage: isLeakage,
                dangerColor: dangerColor,
              ),

              // Siren Audio Banner (if active)
              AnimatedBuilder(
                animation: AudioAlarmService(),
                builder: (context, _) {
                  final alarm = AudioAlarmService();
                  if (!alarm.isPlaying && !alarm.isMuted) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: alarm.isPlaying
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: alarm.isPlaying ? Colors.redAccent : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alarm.isPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: alarm.isPlaying ? Colors.redAccent : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alarm.isPlaying
                                ? '🚨 ไซเรนเตือนภัยกำลังทำงาน!'
                                : 'ปิดเสียงไซเรนชั่วคราวแล้ว',
                            style: TextStyle(
                              color: alarm.isPlaying ? Colors.redAccent : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (alarm.isPlaying) {
                              alarm.mute();
                            } else {
                              alarm.resetMute();
                              alarm.startSiren();
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: alarm.isPlaying ? Colors.redAccent : Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  alarm.isPlaying ? Icons.volume_off : Icons.volume_up,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  alarm.isPlaying ? 'ปิดเสียง' : 'เปิดเสียง',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (isWarning) ...[
                // In Warning state: primary button is 1784 Helpline, secondary is close window
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                    label: const Text(
                      'โทรสายด่วน ปภ. รับมือภัยพิบัติ (1784)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse('tel:1784');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'รับทราบสถานการณ์ (ปิดหน้าต่าง)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else ...[
                // In Critical Flood / Leakage: primary is emergency phone call (191)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                    label: const Text(
                      'โทรสายด่วนขอความช่วยเหลือ (191)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse('tel:191');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                    label: const Text(
                      'โทรสายด่วน ปภ. รับมือภัยพิบัติ (1784)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse('tel:1784');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'รับทราบสถานการณ์ (ปิดหน้าต่าง)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGuidelinesCard({
    required bool isWarning,
    required bool isLeakage,
    required Color dangerColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dangerColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWarning
                    ? Icons.checklist_rounded
                    : (isLeakage ? Icons.electric_bolt_rounded : Icons.health_and_safety_rounded),
                color: dangerColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isWarning
                      ? 'วิธีการรับมือและข้อควรปฏิบัติ (ระดับเฝ้าระวัง)'
                      : (isLeakage
                          ? 'ข้อควรปฏิบัติฉุกเฉิน (ไฟฟ้ารั่ว)'
                          : 'ข้อควรปฏิบัติฉุกเฉิน (ระดับวิกฤต)'),
                  style: TextStyle(
                    color: dangerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isWarning) ...[
            _buildGuidelineItem(
              '📦',
              'ยกของมีค่าขึ้นที่สูง',
              'ย้ายของใช้และเครื่องใช้ไฟฟ้าขึ้นที่สูงพ้นน้ำ',
            ),
            _buildGuidelineItem(
              '🚗',
              'เตรียมยานพาหนะ',
              'นำรถไปจอดบนพื้นที่ดอนหรือจุดปลอดภัย',
            ),
            _buildGuidelineItem(
              '🔋',
              'สำรองพลังงาน',
              'ชาร์จมือถือ สำรองไฟ และเตรียมไฟฉาย',
            ),
            _buildGuidelineItem(
              '📢',
              'ติดตามสถานการณ์',
              'เช็กระดับน้ำในแอปและข่าวสารต่อเนื่อง',
            ),
          ] else if (isLeakage) ...[
            _buildGuidelineItem(
              '🚫',
              'ห้ามเข้าใกล้แหล่งน้ำ',
              'งดเดินลุยน้ำและห้ามแตะเสาไฟหรือโลหะ',
            ),
            _buildGuidelineItem(
              '⚡',
              'ปลดคัทเอาท์หลัก',
              'ตัดกระแสไฟฟ้าตู้ควบคุมหลักทันที',
            ),
            _buildGuidelineItem(
              '📞',
              'แจ้งการไฟฟ้าด่วน',
              'โทร 1130 หรือ 1129 ให้ช่างตัดไฟ',
            ),
          ] else ...[
            _buildGuidelineItem(
              '⚡',
              'ตัดสะพานไฟทันที',
              'สับคัตเอาต์ตัดกระแสไฟป้องกันไฟดูด',
            ),
            _buildGuidelineItem(
              '🚪',
              'อพยพไปยังที่ปลอดภัย',
              'พาคนและสัตว์เลี้ยงเคลื่อนย้ายขึ้นที่สูง',
            ),
            _buildGuidelineItem(
              '🚫',
              'ห้ามลุยกระแสน้ำเชี่ยว',
              'หลีกเลี่ยงการเดินหรือขับรถผ่านน้ำหลาก',
            ),
            _buildGuidelineItem(
              '📞',
              'ขอความช่วยเหลือฉุกเฉิน',
              'โทรสายด่วน 191 หรือ ปภ. 1784 ทันที',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String iconText, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(iconText, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

