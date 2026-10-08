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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments as DeviceData?;
      final targetDev = widget.device ?? args;
      if (targetDev != null) {
        final bool isSirenActive = targetDev.isFloodEmergency ||
            targetDev.waterLevel >= 50.0 ||
            targetDev.earlyWarningSeverity == EarlyWarningSeverity.critical;
        if (isSirenActive && AudioAlarmService().isAlarmEnabled) {
          AudioAlarmService().startSiren();
        }
      }
    });
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
    final String targetId = widget.device?.id ?? argsDevice?.id ?? sensor.selectedDeviceId;
    final DeviceData? liveDev = sensor.devices[targetId];
    final DeviceData? targetDevice = liveDev ??
        widget.device ??
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

    const Distance distanceCalc = Distance();
    final double? distanceMeters = userLatLng != null
        ? distanceCalc.as(LengthUnit.Meter, userLatLng, devLatLng)
        : null;
    final bool isWithin100Km = distanceMeters != null && distanceMeters <= 100000.0;

    final double waterLevel = targetDevice.waterLevel;
    final bool isEmergency = targetDevice.isFloodEmergency || waterLevel >= 50.0;
    final bool isCriticalWater = targetDevice.isFloodDanger || waterLevel >= 30.0;

    final bool isEWCritical = targetDevice.earlyWarningSeverity == EarlyWarningSeverity.critical;
    final bool isEWAlert = targetDevice.earlyWarningSeverity == EarlyWarningSeverity.alert;
    final bool isEWAdvisory = targetDevice.earlyWarningSeverity == EarlyWarningSeverity.advisory;

    final bool isCritical = isEmergency || isCriticalWater || isEWCritical;
    final bool isAdvanceAlert = !isCritical && isEWAlert;

    // Color definitions based on severity
    final Color primaryColor = isEmergency
        ? const Color(0xFFDC2626)
        : (isCritical
            ? const Color(0xFFEF4444)
            : (isAdvanceAlert ? const Color(0xFFF97316) : const Color(0xFFEAB308)));

    final String severityTitle;
    final String categoryBanner;
    final String badgeText;
    final String safetyAdvice;
    final IconData hazardIcon;

    if (isEmergency) {
      badgeText = 'วิกฤตสูงสุด';
      categoryBanner = 'ระบบเตือนภัยวิกฤตสูงสุด (Emergency Level)';
      hazardIcon = Icons.emergency_rounded;
      severityTitle = 'สถานะ : วิกฤตสูงสุด';
      safetyAdvice = 'วิธีรับมือ: ตัดสะพานไฟ • อพยพขึ้นที่สูงทันที • ห้ามลุยน้ำเชี่ยว';
    } else if (isCritical) {
      badgeText = isEWCritical ? 'วิกฤตล่วงหน้า' : 'วิกฤต';
      categoryBanner = isEWCritical
          ? 'ระบบเตือนภัยล่วงหน้าขั้นวิกฤต (Flash Flood Threat)'
          : 'ระบบเตือนภัยวิกฤต (Crisis Level)';
      hazardIcon = isEWCritical ? Icons.bolt_rounded : Icons.crisis_alert_rounded;
      if (isEWCritical) {
        severityTitle = 'สถานะ : วิกฤตเตือนภัยล่วงหน้า';
        safetyAdvice = 'วิธีรับมือ: เสี่ยงน้ำท่วมฉับพลัน • เร่งยกของขึ้นที่สูง • ห้ามสัญจรผ่าน';
      } else {
        severityTitle = 'สถานะ : วิกฤต';
        safetyAdvice = 'วิธีรับมือ: ยกของขึ้นที่สูง • สับคัตเอาต์ตัดไฟ • ห้ามรถทุกชนิดผ่าน';
      }
    } else if (isAdvanceAlert) {
      badgeText = 'เตือนภัยล่วงหน้า';
      categoryBanner = 'ระบบเตือนภัยล่วงหน้า (Early Warning System)';
      hazardIcon = Icons.trending_up_rounded;
      severityTitle = 'สถานะ : เตือนภัยล่วงหน้า';
      safetyAdvice = 'วิธีรับมือ: เตรียมยกของขึ้นที่สูง • เคลื่อนย้ายรถไปที่ดอน • ติดตามระดับน้ำใกล้ชิด';
    } else {
      badgeText = 'เฝ้าระวัง';
      categoryBanner = 'ระบบเฝ้าระวังระดับน้ำ (Water Level Watch)';
      hazardIcon = isEWAdvisory ? Icons.cloudy_snowing : Icons.warning_amber_rounded;
      if (isEWAdvisory) {
        severityTitle = 'สถานะ : เฝ้าระวังล่วงหน้า';
      } else {
        severityTitle = 'สถานะ : เฝ้าระวัง';
      }
      safetyAdvice = 'วิธีรับมือ: เตรียมยกของมีค่า • เคลื่อนย้ายรถไปที่ปลอดภัย • เฝ้าระวังสภาพอากาศ';
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
                            AudioAlarmService().stopSiren();
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

                      // 2. ปุ่มปิดเสียงวิกฤต
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
                          Icon(isCritical ? Icons.emergency_rounded : (isAdvanceAlert ? Icons.warning_amber_rounded : Icons.info_outline_rounded), color: primaryColor, size: 14),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              badgeText,
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
                categoryBanner,
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
              const SizedBox(height: 20),

              // กล่องข้อมูลสรุปหลัก: 1. แจ้งเตือนมาจากอุปกรณ์ไหน 2. ตัวเราห่างจากอุปกรณ์แค่ไหน
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 1. แจ้งมาจากอุปกรณ์ไหน
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.sensors_rounded, color: primaryColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'แจ้งเตือนมาจากอุปกรณ์',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                targetDevice.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'รหัส: ${targetDevice.id} (${targetDevice.stationTypeName}) • ระดับน้ำ: ${waterLevel.toStringAsFixed(1)} ซม.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ระยะเซนเซอร์วัดได้: ${targetDevice.sensorDistance.toStringAsFixed(1)} ซม. (ติดสูง 100 ซม.)',
                                style: TextStyle(color: Colors.grey.shade300, fontSize: 11.5),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'ฮาร์ดแวร์: ${targetDevice.hardwareStatusText}',
                                style: TextStyle(color: primaryColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'สัญจร: ${targetDevice.trafficImpactText}',
                                style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    // 2. ตัวเราห่างจากอุปกรณ์แค่ไหน
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Colors.lightBlueAccent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ตัวเราห่างจากอุปกรณ์',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    distText,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isWithin100Km ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (isWithin100Km ? Colors.green : Colors.orange).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      isWithin100Km ? 'ในรัศมี 100 กม.' : 'นอกรัศมี 100 กม.',
                                      style: TextStyle(
                                        color: isWithin100Km ? Colors.greenAccent : Colors.orangeAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    // 2.1 พยากรณ์ระดับน้ำล่วงหน้า & ปัจจัยเสี่ยงฝน (Early Warning)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: (isAdvanceAlert || isEWCritical)
                            ? primaryColor.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (isAdvanceAlert || isEWCritical)
                              ? primaryColor.withValues(alpha: 0.5)
                              : primaryColor.withValues(alpha: 0.3),
                          width: (isAdvanceAlert || isEWCritical) ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                (isAdvanceAlert || isEWCritical)
                                    ? Icons.bolt_rounded
                                    : Icons.auto_graph_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (isAdvanceAlert || isEWCritical)
                                      ? '⚡ ข้อมูลเตือนภัยล่วงหน้า (Sensor & Weather Fusion):'
                                      : 'พยากรณ์ระดับน้ำล่วงหน้า (ประมวลผลผ่าน App):',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (isAdvanceAlert || isEWCritical) ...[
                            Text(
                              '• น้ำขึ้นเร็วจากเซนเซอร์: ${targetDevice.risingSpeed >= 0 ? '+' : ''}${targetDevice.risingSpeed.toStringAsFixed(1)} ซม./ชม. (รวมฝน: +${targetDevice.compoundRisingSpeed.toStringAsFixed(1)} ซม./ชม.)\n'
                              '• โอกาสฝนตกในพื้นที่: ${targetDevice.forecastRainProb30}%\n'
                              '• คาดการณ์เวลา: ${targetDevice.compoundTimeToDangerText}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            '📈 คาดการณ์ระดับน้ำ: อีก 30 นาที: ${targetDevice.predictedWaterLevel30.toStringAsFixed(1)} ซม. | อีก 60 นาที: ${targetDevice.predictedWaterLevel60.toStringAsFixed(1)} ซม.',
                            style: TextStyle(
                              color: (isAdvanceAlert || isEWCritical) ? const Color(0xFFFDE68A) : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 3. วิธีรับมือและป้องกันตนเองเบื้องต้น (Minimalist)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: primaryColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              safetyAdvice,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              if (isCritical) ...[
                // ในสภาวะวิกฤต: แสดงปุ่ม SOS และโทร 191 / 1784
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
                          SosEmergencyModal.show(context);
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
                TextButton.icon(
                  onPressed: () {
                    AudioAlarmService().stopSiren();
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
                ),
              ] else ...[
                // ในสภาวะเฝ้าระวัง และเตือนภัยล่วงหน้า: แสดงโทร 1784 และปุ่มรับทราบสถานการณ์ (มินิมอล)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Colors.amberAccent),
                    label: const Text(
                      'โทรสายด่วน ปภ. รับมือภัยพิบัติ (1784)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('tel:1784');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    AudioAlarmService().stopSiren();
                    Navigator.pop(context);
                  },
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
