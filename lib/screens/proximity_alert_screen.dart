import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sensor_provider.dart';
import '../providers/location_provider.dart';
import '../services/audio_alarm_service.dart';
import '../widgets/sos_emergency_modal.dart';
import '../widgets/alert_manager.dart';

class ProximityAlertScreen extends StatefulWidget {
  final DeviceData? device;

  const ProximityAlertScreen({super.key, this.device});

  @override
  State<ProximityAlertScreen> createState() => _ProximityAlertScreenState();
}

class _ProximityAlertScreenState extends State<ProximityAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _calculateDistanceText(LatLng? userPos, LatLng targetPos) {
    if (userPos == null) return 'ไม่ทราบระยะห่าง';
    const Distance distance = Distance();
    final double meters = distance.as(LengthUnit.Meter, userPos, targetPos);
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} กม.';
    }
    return '${meters.toInt()} เมตร';
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final location = context.watch<LocationProvider>();

    // Use passed device or route argument or selected device or first available
    final DeviceData? argsDevice =
        ModalRoute.of(context)?.settings.arguments as DeviceData?;
    final DeviceData? targetDevice = widget.device ??
        argsDevice ??
        sensor.currentDevice ??
        (sensor.devices.isNotEmpty ? sensor.devices.values.first : null);

    if (targetDevice == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ไม่พบข้อมูลจุดเสี่ยง', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('กลับ'),
              ),
            ],
          ),
        ),
      );
    }

    final userPos = location.currentPosition;
    final LatLng? userLatLng =
        userPos != null ? LatLng(userPos.latitude, userPos.longitude) : null;
    final LatLng devLatLng = LatLng(targetDevice.lat, targetDevice.lng);
    final String distText = _calculateDistanceText(userLatLng, devLatLng);

    final bool isLeakage = targetDevice.isElectricalLeakage;
    final double waterLevel = targetDevice.waterLevel;
    final bool isCriticalWater = waterLevel >= 60.0;
    final bool isFloodDanger = targetDevice.isFloodDanger;

    final bool isEWCritical = targetDevice.earlyWarningSeverity == EarlyWarningSeverity.critical;
    final bool isEWAlert = targetDevice.earlyWarningSeverity == EarlyWarningSeverity.alert;
    final bool isEWAdvisory = targetDevice.earlyWarningSeverity == EarlyWarningSeverity.advisory;
    final bool isEarlyWarning = isEWCritical || isEWAlert || isEWAdvisory;

    final bool isCritical = isLeakage || isCriticalWater || isFloodDanger || isEWCritical;
    final bool isWarning = !isCritical && (waterLevel >= 40.0 || targetDevice.rainfall >= 30.0 || isEWAlert);

    // Color definitions based on severity
    final Color primaryColor = isCritical
        ? (isLeakage ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
        : (isWarning ? const Color(0xFFF97316) : const Color(0xFFEAB308));

    // Dynamic Retreat Guidance
    final String severityTitle;
    final String retreatCommand;
    final String retreatDistance;
    final String guidanceDescription;
    final IconData hazardIcon;

    if (isLeakage) {
      severityTitle = 'อันตรายสูงสุด: ตรวจพบกระแสไฟฟ้ารั่วในน้ำ!';
      retreatCommand = 'ห้ามเข้าใกล้เด็ดขาด! ให้หยุดและถอยห่างทันที';
      retreatDistance = 'ถอยห่างออกไปอย่างน้อย 300 - 500 เมตร';
      guidanceDescription =
          'ตรวจพบกระแสไฟฟ้ารั่วไหลลงสู่น้ำท่วมขัง เสี่ยงต่อการถูกไฟดูดถึงแก่ชีวิต ห้ามเดินลุยน้ำหรือขับขี่ยานพาหนะผ่านบริเวณนี้เด็ดขาด ให้กลับรถหรือถอยหลังทันที';
      hazardIcon = Icons.bolt_rounded;
    } else if (isCriticalWater || isFloodDanger) {
      severityTitle = 'อันตรายวิกฤต: ระดับน้ำท่วมสูงลึกวิกฤต!';
      retreatCommand = 'น้ำลึกอันตราย! ห้ามเข้าใกล้เด็ดขาด';
      retreatDistance = 'ถอยห่างออกไปอย่างน้อย 300 - 500 เมตร';
      guidanceDescription =
          'ระดับน้ำท่วมสูงเกิน 60 ซม. กระแสน้ำอาจเชี่ยวกรากและมองไม่เห็นท่อระบายน้ำ เสี่ยงต่อการพลัดตกหรือรถยนต์ถูกกระแสน้ำพัดลอยจมน้ำ ให้หยุดรถและถอยห่างทันที';
      hazardIcon = Icons.warning_amber_rounded;
    } else if (isEWCritical) {
      severityTitle = '🚨 เตือนภัยล่วงหน้าขั้นวิกฤต: คาดการณ์เสี่ยงน้ำท่วมฉับพลัน!';
      retreatCommand = 'โปรดหลีกเลี่ยงเส้นทางนี้ทันที! เสี่ยงน้ำท่วมสูงข้างหน้า';
      retreatDistance = 'เปลี่ยนเส้นทางทันที / ถอยห่างจากพื้นที่ลุ่มต่ำ 500 - 1,000 เมตร';
      guidanceDescription =
          'ระบบวิเคราะห์ความเร็วเซนเซอร์ + พยากรณ์ฝน AI คาดการณ์น้ำขึ้นเร็วมากถึง +${targetDevice.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. (เซนเซอร์: ${targetDevice.risingSpeed.toStringAsFixed(1)} ซม./ชม., โอกาสฝน: ${targetDevice.forecastRainProb30}%) ${targetDevice.compoundTimeToDangerText} อาจเกิดน้ำท่วมสูงฉับพลันบนผิวทาง ขอให้ผู้ใช้หลีกเลี่ยงเส้นทางนี้ทันทีและใช้เส้นทางเลี่ยงที่ปลอดภัย';
      hazardIcon = Icons.alt_route_rounded;
    } else if (isEWAlert) {
      severityTitle = '⚠️ เตือนภัยล่วงหน้า: ระดับน้ำมีแนวโน้มขึ้นเร็ว เสี่ยงน้ำท่วมทาง';
      retreatCommand = 'โปรดหลีกเลี่ยงเส้นทางนี้! แนะนำให้ใช้ทางเลี่ยงล่วงหน้า';
      retreatDistance = 'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง';
      guidanceDescription =
          'ตรวจพบแนวโน้มระดับน้ำเพิ่มขึ้นรวดเร็ว +${targetDevice.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. ร่วมกับมีความเสี่ยงฝนตกในพื้นที่ (${targetDevice.forecastRainProb30}%) ${targetDevice.compoundTimeToDangerText} อาจมีน้ำท่วมขังผิวจราจร แนะนำให้วางแผนเปลี่ยนเส้นทางหรือกลับรถเพื่อความปลอดภัย';
      hazardIcon = Icons.alt_route_rounded;
    } else if (isWarning) {
      severityTitle = 'เตือนภัย: ระดับน้ำท่วมสูง รถเล็กห้ามผ่าน';
      retreatCommand = 'รถเล็กงดผ่าน! ให้กลับรถและเปลี่ยนเส้นทาง';
      retreatDistance = 'ถอยห่างอย่างน้อย 500 เมตร หรือใช้ทางเลี่ยง';
      guidanceDescription =
          'ระดับน้ำท่วมผิวจราจรสูง 40-59 ซม. น้ำอาจเข้าท่อไอเสียทำให้เครื่องยนต์ดับติดค้างในน้ำได้ แนะนำให้กลับรถและใช้เส้นทางเลี่ยงที่ปลอดภัย';
      hazardIcon = Icons.report_problem_rounded;
    } else if (isEWAdvisory) {
      severityTitle = 'ℹ️ เฝ้าระวังล่วงหน้า: สภาพอากาศอาจส่งผลให้น้ำท่วมขัง';
      retreatCommand = 'ชะลอความเร็ว ระวังจุดน้ำท่วมและเตรียมเส้นทางเลี่ยง';
      retreatDistance = 'เฝ้าระวังในระยะ 800 - 1,000 เมตร';
      guidanceDescription =
          'พยากรณ์โอกาสฝนตก ${targetDevice.forecastRainProb30}% อัตราการเพิ่มระดับน้ำคาดการณ์ +${targetDevice.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม. โปรดชะลอความเร็ว ระมัดระวังน้ำท่วมขังรอระบายข้างหน้า และเตรียมทางเลี่ยงหากฝนตกต่อเนื่อง';
      hazardIcon = Icons.cloudy_snowing;
    } else {
      severityTitle = 'เฝ้าระวัง: พื้นที่น้ำท่วมขังรอระบายข้างหน้า';
      retreatCommand = 'ชะลอความเร็ว ระวังจุดน้ำท่วมข้างหน้า';
      retreatDistance = 'เฝ้าระวังในระยะ 800 - 1,000 เมตร';
      guidanceDescription =
          'มีน้ำท่วมขังรอการระบายในพื้นที่ข้างหน้า โปรดชะลอความเร็วเพื่อลดคลื่นน้ำ หลีกเลี่ยงการเดินเท้าลุยน้ำ และระวังสัตว์มีพิษ';
      hazardIcon = Icons.info_outline_rounded;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Close, Relocate & Mute Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. ปุ่มปิด / ย่อหน้าต่าง
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          tooltip: isCritical ? 'ย่อหน้าต่างเตือนภัย (จะเด้งเตือนซ้ำตลอดเวลา)' : 'ปิดหน้าต่างเตือนภัย',
                          onPressed: () {
                            AudioAlarmService().mute();
                            Navigator.pop(context);
                            if (isCritical) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ ระดับน้ำยังคงวิกฤต! หน้าต่างเตือนภัยจะเด้งเตือนซ้ำตลอดเวลาเพื่อความปลอดภัย'),
                                  backgroundColor: Colors.redAccent,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. ปุ่มย้ายตำแหน่ง / เปิดแผนที่ดูทางเลี่ยงหนีน้ำ
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.45)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.near_me_rounded, color: Colors.lightBlueAccent, size: 20),
                          tooltip: 'ย้ายตำแหน่ง / ดูเส้นทางเลี่ยงบนแผนที่',
                          onPressed: () {
                            sensor.selectDevice(targetDevice.id);
                            AlertManager.grantEvacuationGracePeriod(const Duration(seconds: 30));
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/map');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. ปุ่มปิดเสียงวิกฤต (ข้างๆ ปุ่มย้ายตำแหน่ง)
                      AnimatedBuilder(
                        animation: AudioAlarmService(),
                        builder: (context, _) {
                          final alarm = AudioAlarmService();
                          final bool isPlaying = alarm.isPlaying;
                          final bool isEnabled = alarm.isAlarmEnabled;
                          return Container(
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? Colors.redAccent.withValues(alpha: 0.28)
                                  : (isEnabled
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPlaying
                                    ? Colors.redAccent
                                    : (isEnabled ? Colors.green.withValues(alpha: 0.5) : Colors.white24),
                                width: isPlaying ? 1.5 : 1.0,
                              ),
                              boxShadow: isPlaying
                                  ? [
                                      BoxShadow(
                                        color: Colors.redAccent.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.volume_up_rounded
                                    : (isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                                color: isPlaying
                                    ? Colors.redAccent
                                    : (isEnabled ? Colors.greenAccent : Colors.white70),
                                size: 20,
                              ),
                              tooltip: isPlaying
                                  ? 'ไซเรนกำลังดัง (กดเพื่อปิดเสียง)'
                                  : (isEnabled ? 'เปิดเสียงเตือนภัยอยู่ (กดเพื่อปิด)' : 'ปิดเสียงเตือนภัยอยู่ (กดเพื่อเปิด)'),
                              onPressed: () {
                                alarm.toggleAlarm(isCurrentlyCritical: isCritical);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Right Side: Status Badge Pill
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isCritical ? Icons.emergency_rounded : Icons.near_me_rounded, color: primaryColor, size: 14),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isCritical ? '🚨 สภาวะวิกฤต' : 'Proximity GPS',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pulsing Big Danger Icon
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(hazardIcon, color: primaryColor, size: 52),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Emergency Title Banner
              Text(
                isEarlyWarning
                    ? 'ตรวจพบความเสี่ยงน้ำท่วมล่วงหน้า!'
                    : 'คุณกำลังเข้าใกล้จุดเสี่ยงอันตราย!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                severityTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              if (isCritical) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.85), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEWCritical
                                  ? 'เตือนภัยล่วงหน้าขั้นวิกฤต - แสดงหน้าต่างเตือนภัยตลอดเวลา!'
                                  : 'ระดับน้ำขึ้นวิกฤต - แสดงหน้าต่างเตือนภัยตลอดเวลา!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isEWCritical
                                  ? 'ระบบวิเคราะห์พบน้ำขึ้นเร็วและเสี่ยงน้ำท่วมฉับพลันสูง หน้าต่างเตือนภัยนี้จะแสดงผลต่อเนื่องเพื่อให้ท่านหลีกเลี่ยงเส้นทางทันเวลา'
                                  : 'หน้าต่างเตือนภัยนี้จะแจ้งเตือนตลอดเวลาต่อเนื่อง เพื่อความปลอดภัยสูงสุด จนกว่าระดับน้ำจะลดลงสู่เกณฑ์ปกติ หรือท่านถอยห่างพ้นจุดเสี่ยง',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Target Station & Real-Time Distance Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Colors.blueAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                targetDevice.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'สถานีรหัส: ${targetDevice.id}',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricChip(
                          title: 'ระยะห่างปัจจุบัน',
                          value: distText,
                          color: primaryColor,
                          icon: Icons.directions_walk_rounded,
                        ),
                        Container(width: 1, height: 36, color: Colors.white12),
                        _buildMetricChip(
                          title: 'ระดับน้ำที่จุดนั้น',
                          value: '${waterLevel.toStringAsFixed(1)} ซม.',
                          color: isCritical ? Colors.redAccent : Colors.orangeAccent,
                          icon: Icons.water_drop_rounded,
                        ),
                        if (isLeakage) ...[
                          Container(width: 1, height: 36, color: Colors.white12),
                          _buildMetricChip(
                            title: 'กระแสไฟฟ้า',
                            value: 'ไฟฟ้ารั่ว!',
                            color: Colors.amber,
                            icon: Icons.bolt_rounded,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Early Warning & Compound Speed Analysis Card (เตือนภัยล่วงหน้า & คำแนะนำเลี่ยงเส้นทาง)
              if (isEarlyWarning) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.speed_rounded, color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'วิเคราะห์ความเร็ว & เตือนภัยล่วงหน้า (AI)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  targetDevice.smartEarlyWarningTitle,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ความเร็วรวมคาดการณ์', style: TextStyle(color: Colors.grey, fontSize: 10.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '+${targetDevice.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม.',
                                    style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('โอกาสฝน 30 นาที', style: TextStyle(color: Colors.grey, fontSize: 10.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${targetDevice.forecastRainProb30}% (${targetDevice.rainfall.toStringAsFixed(1)} มม.)',
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                targetDevice.compoundTimeToDangerText,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.alt_route_rounded, color: Colors.lightGreenAccent, size: 16),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'คำแนะนำ: อาจเกิดน้ำท่วมสูง โปรดหลีกเลี่ยงเส้นทางนี้และใช้ทางเลี่ยง',
                              style: TextStyle(
                                color: Colors.lightGreenAccent,
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
                const SizedBox(height: 18),
              ],

              // Big Retreat Instruction Card (Highlight requirement: "ให้ถอยห่างตามระดับความอันตรายของระดับน้ำ")
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.22),
                      primaryColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pan_tool_rounded, color: Colors.black87, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            retreatCommand,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ระยะปลอดภัยที่แนะนำ: $retreatDistance',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      guidanceDescription,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Siren Sound Control Banner (if leakage or critical)
              AnimatedBuilder(
                animation: AudioAlarmService(),
                builder: (context, _) {
                  final alarm = AudioAlarmService();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: alarm.isPlaying
                          ? Colors.red.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: alarm.isPlaying
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alarm.isPlaying ? Icons.campaign_rounded : Icons.volume_off_rounded,
                          color: alarm.isPlaying ? Colors.redAccent : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alarm.isPlaying
                                ? '🚨 ไซเรนเตือนภัยกำลังทำงาน!'
                                : 'เสียงไซเรนปิดอยู่',
                            style: TextStyle(
                              color: alarm.isPlaying ? Colors.redAccent : Colors.grey.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: alarm.isPlaying
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.white10,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            alarm.isPlaying ? Icons.volume_off : Icons.volume_up,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: Text(
                            alarm.isPlaying ? 'ปิดเสียง' : 'เปิดเสียง',
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                          onPressed: () {
                            if (alarm.isPlaying) {
                              alarm.mute();
                            } else {
                              alarm.resetMute();
                              alarm.startSiren();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Action Buttons
              // 1. Open Map & Route Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.map_rounded, size: 20),
                label: const Text(
                  'เปิดแผนที่ดูจุดเสี่ยง & ทางเลี่ยง (Safe Route)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  sensor.selectDevice(targetDevice.id);
                  AlertManager.grantEvacuationGracePeriod(const Duration(seconds: 30));
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/map');
                },
              ),
              const SizedBox(height: 10),

              // 2. SOS Emergency Button & Hotline Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.sos_rounded, size: 20),
                      label: const Text(
                        'ขอความช่วยเหลือ SOS',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        AlertManager.grantEvacuationGracePeriod(const Duration(seconds: 30));
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SosEmergencyModal(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                      label: const Text(
                        'โทร 191 / 1784',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        AlertManager.grantEvacuationGracePeriod(const Duration(seconds: 30));
                        final uri = Uri.parse('tel:1784');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Dismiss & Snooze Button
              if (isCritical)
                TextButton.icon(
                  onPressed: () {
                    AudioAlarmService().mute();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ระดับน้ำยังคงวิกฤต! หน้าต่างเตือนภัยจะเด้งซ้ำตลอดเวลาเพื่อความปลอดภัย',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.redAccent,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync_problem_rounded, color: Colors.orangeAccent, size: 16),
                  label: const Text(
                    'ย่อหน้าต่างชั่วคราว (ระบบจะเด้งเตือนซ้ำตลอดเวลาเนื่องจากระดับน้ำวิกฤต)',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    AudioAlarmService().mute();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'รับทราบสถานการณ์ (ปิดการเตือนชั่วคราว)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
