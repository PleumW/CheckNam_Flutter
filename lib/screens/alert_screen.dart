import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_alarm_service.dart';

class AlertScreen extends StatelessWidget {
  final String title;
  final String waterLevel;
  final String type; // 'leakage' or 'flood'

  const AlertScreen({
    super.key,
    required this.title,
    required this.waterLevel,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLeakage = type == 'leakage';
    final Color dangerColor = isLeakage ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
            ),
            child: IconButton(
              icon: const Icon(Icons.near_me_rounded, color: Colors.lightBlueAccent, size: 20),
              tooltip: 'ย้ายตำแหน่ง / ดูแผนที่ทางเลี่ยง',
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
            ),
          ),
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
                  tooltip: isPlaying ? 'ปิดเสียงไซเรนวิกฤต' : 'เปิดเสียงไซเรนวิกฤต',
                  onPressed: () {
                    if (isPlaying) {
                      alarm.mute();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔇 ปิดเสียงไซเรนวิกฤตชั่วคราวแล้ว'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.black87,
                        ),
                      );
                    } else {
                      alarm.resetMute();
                      alarm.startSiren();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔊 เปิดเสียงไซเรนวิกฤตแล้ว'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Minimal Hazard Icon Container with ambient glow
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: dangerColor.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: dangerColor.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 8,
                    )
                  ],
                ),
                child: Icon(
                  isLeakage ? Icons.bolt_rounded : Icons.warning_amber_rounded,
                  size: 72,
                  color: dangerColor,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                isLeakage ? 'แจ้งเตือนอันตรายไฟฟ้ารั่ว' : 'แจ้งเตือนระดับน้ำวิกฤต',
                style: TextStyle(
                  color: dangerColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),
              
              // Minimal Water Level Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.water_drop_rounded, color: dangerColor, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ระดับน้ำปัจจุบัน', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              waterLevel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('ซม.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: dangerColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'วิกฤต',
                                style: TextStyle(color: dangerColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Siren Audio Banner
              AnimatedBuilder(
                animation: AudioAlarmService(),
                builder: (context, _) {
                  final alarm = AudioAlarmService();
                  if (!alarm.isPlaying && !alarm.isMuted) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: alarm.isPlaying ? Colors.redAccent.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: alarm.isPlaying ? Colors.redAccent : Colors.grey.withValues(alpha: 0.3)),
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
                            alarm.isPlaying ? '🚨 ไซเรนเตือนภัยกำลังทำงาน!' : 'ปิดเสียงไซเรนชั่วคราวแล้ว',
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
                                Icon(alarm.isPlaying ? Icons.volume_off : Icons.volume_up, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  alarm.isPlaying ? 'ปิดเสียง' : 'เปิดเสียง',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
              const Spacer(),
              
              // Action Buttons
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
                  label: const Text('โทรสายด่วนขอความช่วยเหลือ (191)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final Uri url = Uri.parse('tel:191');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  label: const Text('ดูคู่มือการปฏิบัติตัวเมื่อเกิดภัย', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      isLeakage ? '/guide_leakage' : '/guide_flood',
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

