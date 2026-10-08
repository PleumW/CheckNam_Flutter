import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/weather_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/mock_weather_dialog.dart';
import '../services/audio_alarm_service.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final TextEditingController _waterController = TextEditingController();
  bool _isOnline = true;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _waterController.addListener(_onWaterChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sensor = context.read<SensorProvider>();
      if (sensor.devices.isNotEmpty) {
        setState(() {
          _selectedDeviceId = sensor.selectedDeviceId.isNotEmpty && sensor.devices.containsKey(sensor.selectedDeviceId)
              ? sensor.selectedDeviceId
              : sensor.devices.keys.first;
          _loadDeviceData();
        });
      }
    });
  }

  void _onWaterChanged() {
    if (mounted) setState(() {});
  }

  void _loadDeviceData() {
    if (_selectedDeviceId == null) return;
    final sensor = context.read<SensorProvider>();
    final device = sensor.devices[_selectedDeviceId];
    if (device != null) {
      _waterController.text = device.waterLevel.toStringAsFixed(1);
      _isOnline = device.isDeviceOnline;
    }
  }

  void _sendSimulation({double? water, bool? isOnline}) {
    if (_selectedDeviceId == null) return;

    final double waterVal = water ?? (double.tryParse(_waterController.text) ?? 0.0);
    final bool onlineVal = isOnline ?? _isOnline;

    if (water != null) _waterController.text = water.toStringAsFixed(1);
    if (isOnline != null) setState(() => _isOnline = isOnline);

    final sensor = context.read<SensorProvider>();
    final currentDevice = sensor.devices[_selectedDeviceId!];
    final double lat = currentDevice?.lat ?? 13.7563;
    final double lng = currentDevice?.lng ?? 100.5018;
    final double flowVal = currentDevice?.waterFlow ?? 5.0;
    final double rainVal = currentDevice?.rainfall ?? 0.0;

    sensor.simulateDataFromIoT(
      deviceId: _selectedDeviceId!,
      lat: lat,
      lng: lng,
      waterLevel: waterVal,
      waterFlow: flowVal,
      rainfall: rainVal,
      isOnline: onlineVal,
    );

    sensor.selectDevice(_selectedDeviceId!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('ส่งข้อมูลจำลองไปยัง "${currentDevice?.name ?? _selectedDeviceId}" สำเร็จ!'),
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _simulateScenario({
    required String title,
    required double waterLevel,
    double flow = 8.0,
    double rain = 0.0,
    bool isOnline = true,
  }) {
    final sensor = context.read<SensorProvider>();
    final targetId = _selectedDeviceId ?? sensor.selectedDeviceId;
    final currentDev = sensor.devices[targetId] ?? sensor.currentDevice;
    final double lat = currentDev?.lat ?? 13.7563;
    final double lng = currentDev?.lng ?? 100.5018;

    sensor.simulateDataFromIoT(
      deviceId: targetId,
      lat: lat,
      lng: lng,
      waterLevel: waterLevel,
      waterFlow: flow,
      rainfall: rain,
      isOnline: isOnline,
    );
    sensor.selectDevice(targetId);

    setState(() {
      _selectedDeviceId = targetId;
      _loadDeviceData();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('เปิดใช้งานสภาวะจำลอง: $title (ระดับน้ำ ${waterLevel.toStringAsFixed(1)} ซม.) สำเร็จ!'),
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _testTakeoverScreen({required String type}) {
    final sensor = context.read<SensorProvider>();
    final targetId = _selectedDeviceId ?? sensor.selectedDeviceId;
    final currentDev = sensor.devices[targetId] ??
        sensor.currentDevice ??
        (sensor.devices.isNotEmpty ? sensor.devices.values.first : null);

    final String devId = currentDev?.id ?? 'device_1';
    final String devName = currentDev?.name ?? 'สถานีตรวจวัด IoT';
    final double lat = currentDev?.lat ?? 13.7563;
    final double lng = currentDev?.lng ?? 100.5018;

    double waterLevel;
    double waterFlow;
    double rainfall;
    bool isRainingHeavy = false;
    double risingSpeed = 0.0;
    int rainProb = 20;

    if (type == 'emergency') {
      // วิกฤตสูงสุด: 50.0 ซม. ขึ้นไป (เซ็นเซอร์ < 50.0 ซม.)
      waterLevel = 65.0;
      waterFlow = 30.0;
      rainfall = 45.0;
      AudioAlarmService().startSiren();
    } else if (type == 'critical') {
      // วิกฤต: 30.0 – 49.9 ซม. (เซ็นเซอร์ 50.1 – 70.0 ซม.)
      waterLevel = 40.0;
      waterFlow = 15.0;
      rainfall = 20.0;
    } else if (type == 'early_warning') {
      // เตือนภัยล่วงหน้าน้ำพุ่งเร็ว: ระดับน้ำ 15.0 ซม. (ยังไม่ถึงเกณฑ์วิกฤต 30 ซม.) แต่น้ำขึ้นเร็ว + เสี่ยงฝนตกหนัก
      waterLevel = 15.0;
      waterFlow = 15.0;
      rainfall = 10.0;
      isRainingHeavy = false;
      risingSpeed = 12.0;
      rainProb = 80;
    } else {
      // เฝ้าระวัง: 10.0 – 29.9 ซม. (เซ็นเซอร์ 70.1 – 90.0 ซม.)
      waterLevel = 20.0;
      waterFlow = 8.0;
      rainfall = 5.0;
      risingSpeed = 0.0;
      rainProb = 15;
    }

    // อัปเดตข้อมูลระดับน้ำใน SensorProvider ทันทีเพื่อให้ตัวอุปกรณ์เปลี่ยนสถานะตามจริง
    sensor.simulateDataFromIoT(
      deviceId: devId,
      lat: lat,
      lng: lng,
      waterLevel: waterLevel,
      waterFlow: waterFlow,
      rainfall: rainfall,
      risingSpeed: risingSpeed,
      forecastRainProb30: rainProb,
      isOnline: true,
    );
    sensor.selectDevice(devId);

    setState(() {
      _selectedDeviceId = devId;
      _loadDeviceData();
    });

    final testDevice = DeviceData(
      id: devId,
      name: devName,
      lat: lat,
      lng: lng,
      waterLevel: waterLevel,
      waterFlow: waterFlow,
      rainfall: rainfall,
      risingSpeed: risingSpeed,
      isRainingHeavy: isRainingHeavy,
      forecastRainProb30: rainProb,
      waterLevelThreshold: 30.0,
      isOnline: true,
    );

    Navigator.pushNamed(context, '/proximity_alert', arguments: testDevice);
  }

  @override
  void dispose() {
    _waterController.removeListener(_onWaterChanged);
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final uniqueDevices = sensor.uniqueDeviceList;

    if (_selectedDeviceId == null && uniqueDevices.isNotEmpty) {
      final validIds = uniqueDevices.map((d) => d.id).toSet();
      _selectedDeviceId = validIds.contains(sensor.selectedDeviceId)
          ? sensor.selectedDeviceId
          : uniqueDevices.first.id;
      _loadDeviceData();
    }

    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('IoT Simulator'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 72, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'เฉพาะผู้ดูแลระบบ (Admin Only)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'หน้านี้สำหรับผู้ดูแลระบบเพื่อทดสอบระบบจำลอง IoT และสภาวะเตือนภัยเท่านั้น',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('กลับสู่หน้าหลัก'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Simulator (Debug Menu)'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'เครื่องมือจำลองสถานีตรวจวัด IoT เพื่อทดสอบการวิเคราะห์สถานะระดับน้ำและการแจ้งเตือนภัยตามพิกัด GIS',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // -----------------------------------------------------------------
            // แผงทดสอบ Takeover Screen (Modal Direct Test)
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ทดสอบ Takeover Screen (Debug Testing)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'กดเปิดหน้าจอ Takeover เต็มหน้าจอเพื่อทดสอบ UI และปุ่มช่วยเหลือ',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // แถวที่ 1: วิกฤตสูงสุด & วิกฤต
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.emergency_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🚨 วิกฤตสูงสุด (≥50 ซม.)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onPressed: () => _testTakeoverScreen(type: 'emergency'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.crisis_alert_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🔴 วิกฤต (30-49.9 ซม.)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onPressed: () => _testTakeoverScreen(type: 'critical'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // แถวที่ 2: เฝ้าระวัง & เตือนภัยล่วงหน้า
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.warning_amber_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🟠 เฝ้าระวัง (10-29.9 ซม.)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onPressed: () => _testTakeoverScreen(type: 'watch'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.trending_up_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '⚡ เตือนล่วงหน้า (น้ำพุ่ง)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onPressed: () => _testTakeoverScreen(type: 'early_warning'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ปุ่มทดสอบเสียงไซเรนเตือนภัยโดยตรง
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        foregroundColor: Colors.lightBlueAccent,
                        side: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 18, color: Colors.lightBlueAccent),
                      label: const Text(
                        '🔊 ทดสอบเสียงไซเรนฉุกเฉิน (3 วินาที)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        AudioAlarmService().playTestSiren(duration: const Duration(seconds: 3));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.volume_up_rounded, color: Colors.lightBlueAccent, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('กำลังเล่นเสียงไซเรนทดสอบ 3 วินาที (หากไม่ได้ยิน ให้เปิดเสียง Media หรือปิดโหมดเงียบบนมือถือ)'),
                                ),
                              ],
                            ),
                            backgroundColor: Color(0xFF1E293B),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // -----------------------------------------------------------------
            // แผงจำลองสภาพอากาศ & พยากรณ์ฝน (Rain Forecast Mockup)
            // -----------------------------------------------------------------
            _buildWeatherMockupCard(context, sensor),
            const SizedBox(height: 24),

            // Disaster & Flood Scenarios for Selected Station
            const Text('สภาวะจำลองระดับน้ำและภัยพิบัติ (Disaster & Flood Scenarios):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildScenarioTile(
              title: '🟢 สภาวะปกติ (Normal State: 0 – 9.9 ซม.)',
              subtitle: 'ระดับน้ำ 5.0 ซม. (เซ็นเซอร์ 95.0 ซม.) • ไฟเขียวติด • ถนนแห้ง รถผ่านสะดวก',
              color: Colors.green,
              onTap: () => _simulateScenario(
                title: 'สภาวะปกติ',
                waterLevel: 5.0,
                flow: 5.0,
                rain: 0.0,
              ),
            ),
            _buildScenarioTile(
              title: '🟠 สภาวะเฝ้าระวัง (Watch Level: 10.0 – 29.9 ซม.)',
              subtitle: 'ระดับน้ำ 20.0 ซม. (เซ็นเซอร์ 80.0 ซม.) • ไฟเหลืองติด • รถเก๋งเริ่มลำบาก มอเตอร์ไซค์เสี่ยงดับ',
              color: Colors.amber.shade800,
              onTap: () => _simulateScenario(
                title: 'สภาวะเฝ้าระวัง',
                waterLevel: 20.0,
                flow: 12.0,
                rain: 15.0,
              ),
            ),
            _buildScenarioTile(
              title: '🔴 สภาวะวิกฤต (Critical Flood: 30.0 – 49.9 ซม.)',
              subtitle: 'ระดับน้ำ 40.0 ซม. (เซ็นเซอร์ 60.0 ซม.) • ไฟแดงติด Buzzer เงียบ • รถเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด',
              color: Colors.deepOrange,
              onTap: () => _simulateScenario(
                title: 'สภาวะวิกฤต',
                waterLevel: 40.0,
                flow: 20.0,
                rain: 35.0,
              ),
            ),
            _buildScenarioTile(
              title: '🚨 วิกฤตสูงสุด (Emergency Siren: ≥ 50.0 ซม.)',
              subtitle: 'ระดับน้ำ 65.0 ซม. (เซ็นเซอร์ 35.0 ซม.) • ไฟแดงติด ไซเรนดังกระหึ่ม! • รถดับ 100% ห้ามผ่านเด็ดขาด',
              color: Colors.red,
              onTap: () => _simulateScenario(
                title: 'วิกฤตสูงสุด',
                waterLevel: 65.0,
                flow: 35.0,
                rain: 55.0,
              ),
            ),
            _buildScenarioTile(
              title: '⚡ น้ำขึ้นเร็วฉับพลัน (Flash Flood Early Warning)',
              subtitle: 'ระดับน้ำ 32.0 ซม. • อัตราน้ำพุ่งเร็ว +15 ซม./ชม. เตือนภัยล่วงหน้าก่อนวิกฤต',
              color: Colors.purple,
              onTap: () => _simulateScenario(
                title: 'น้ำขึ้นเร็วฉับพลัน',
                waterLevel: 32.0,
                flow: 25.0,
                rain: 45.0,
              ),
            ),
            _buildScenarioTile(
              title: '🧪 สลับไปยัง "device test" (ทดสอบอุปกรณ์)',
              subtitle: 'สลับไปยัง "device test" เพื่อทดสอบและส่งข้อมูลเข้าบอร์ดเสมือน',
              color: Colors.teal,
              onTap: () {
                if (sensor.devices.containsKey('device_test')) {
                  sensor.selectDevice('device_test');
                  setState(() {
                    _selectedDeviceId = 'device_test';
                    _loadDeviceData();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('สลับไปยัง "device test" เรียบร้อยแล้ว'),
                      backgroundColor: Colors.teal,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            const Text('ปรับแต่งเซนเซอร์รายสถานี (Custom Station Tuning):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            if (uniqueDevices.isNotEmpty)
              Builder(
                builder: (context) {
                  final validIds = uniqueDevices.map((d) => d.id).toSet();
                  final effectiveId = validIds.contains(_selectedDeviceId)
                      ? _selectedDeviceId
                      : uniqueDevices.first.id;
                  return DropdownButtonFormField<String>(
                    key: ValueKey(effectiveId),
                    initialValue: effectiveId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'เลือกสถานีที่ต้องการปรับแต่ง',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sensors),
                    ),
                    items: uniqueDevices.map((device) {
                      return DropdownMenuItem(
                        value: device.id,
                        child: Text(
                          '${device.name} (${device.id})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        sensor.selectDevice(val);
                        setState(() {
                          _selectedDeviceId = val;
                          _loadDeviceData();
                        });
                      }
                    },
                  );
                },
              )
            else
              const Text('ไม่พบรายการอุปกรณ์ในระบบ', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 16),

            TextField(
              controller: _waterController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ระดับน้ำขังบนถนน (ซม.)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.water),
              ),
            ),
            
            // การคำนวณระยะเซ็นเซอร์และสถานะตามตารางแบบเรียลไทม์
            _buildLiveSensorCalculationCard(),

            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('จำลองสถานะการเชื่อมต่อบอร์ด 📶'),
              subtitle: Text(_isOnline ? 'สถานะ: ออนไลน์ (🟢 เชื่อมต่ออยู่)' : 'สถานะ: ออฟไลน์ (🔴 ขาดการติดต่อ)'),
              value: _isOnline,
              activeTrackColor: Colors.green,
              onChanged: (val) {
                setState(() {
                  _isOnline = val;
                });
                // ส่งค่าเปลี่ยนสถานะออนไลน์/ออฟไลน์ทันทีเพื่อให้อุปกรณ์เปลี่ยนตาม
                _sendSimulation(isOnline: val);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _sendSimulation(),
                icon: const Icon(Icons.send),
                label: const Text('ส่งข้อมูลจำลองไปยังระบบ (PUSH DATA)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioTile({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      color: color.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onTap,
                child: const Text('จำลอง', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSensorCalculationCard() {
    final double w = double.tryParse(_waterController.text) ?? 0.0;
    final double dist = (100.0 - w).clamp(0.0, 100.0);

    final String tierName;
    final String hwStatus;
    final String traffic;
    final Color tierColor;

    if (w >= 50.0) {
      tierName = '🚨 วิกฤตสูงสุด (Emergency: ≥ 50.0 ซม.)';
      hwStatus = '🔴 ไฟแดงติด • 🔊 ไซเรนดังกระหึ่ม!';
      traffic = 'รถเล็กและรถเก๋งเครื่องดับ 100% ห้ามสัญจรผ่านเด็ดขาด';
      tierColor = Colors.red;
    } else if (w >= 30.0) {
      tierName = '🔴 วิกฤต (Critical: 30.0 – 49.9 ซม.)';
      hwStatus = '🔴 ไฟแดงติด • 🔇 Buzzer เงียบ';
      traffic = 'รถเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด';
      tierColor = Colors.deepOrange;
    } else if (w >= 10.0) {
      tierName = '🟠 เฝ้าระวัง (Warning: 10.0 – 29.9 ซม.)';
      hwStatus = '🟠 ไฟเหลืองติด • 🔇 Buzzer เงียบ';
      traffic = 'รถเก๋งสัญจรลำบาก มอเตอร์ไซค์เสี่ยงดับ';
      tierColor = Colors.amber.shade800;
    } else {
      tierName = '🟢 ปกติ (Normal: 0 – 9.9 ซม.)';
      hwStatus = '🟢 ไฟเขียวติด • 🔇 Buzzer เงียบ';
      traffic = 'รถทุกชนิดสัญจรผ่านได้สะดวก';
      tierColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, size: 18, color: tierColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'สูตร: ระดับน้ำขัง (ซม.) = 100 ซม. - ระยะเซ็นเซอร์',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tierColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• ระดับน้ำบนถนน: ${w.toStringAsFixed(1)} ซม. ➡️ เซ็นเซอร์วัดได้: ${dist.toStringAsFixed(1)} ซม.',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            '• สถานะ: $tierName',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tierColor),
          ),
          const SizedBox(height: 3),
          Text(
            '• ฮาร์ดแวร์: $hwStatus',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            '• สภาพการสัญจร: $traffic',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMockupCard(BuildContext context, SensorProvider sensor) {
    final bool isMock = sensor.isMockWeatherEnabled;
    final mockData = sensor.mockWeatherData;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMock ? Colors.purpleAccent : Colors.blue.withValues(alpha: 0.3),
          width: isMock ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMock ? Colors.purple : Colors.black).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isMock ? Colors.purpleAccent : Colors.blueAccent).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isMock ? (mockData?['icon'] ?? '🌦️') : '🌦️',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'จำลองการพยากรณ์ฝน (Rain Mockup)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        if (isMock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'MOCK ON',
                              style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMock
                          ? 'จำลอง: ${mockData?['description']} • ฝน ${mockData?['precipitation']} mm • โอกาส ${mockData?['prob30']}%'
                          : 'ใช้ทดสอบระบบเตือนภัยล่วงหน้า (Early Warning) ในวันที่ฝนไม่ตกจริง',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMock ? Colors.purpleAccent : Colors.grey,
                        fontWeight: isMock ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Presets 4 Buttons in 2x2 grid (Never overflows)
          const Text('กดเลือกสถานการณ์จำลองฝนล่วงหน้า (Quick Presets):', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMiniPresetBtn(
                      context,
                      sensor,
                      label: '☀️ ปลอดฝน',
                      desc: '0mm (5%)',
                      presetKey: 'sunny',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniPresetBtn(
                      context,
                      sensor,
                      label: '⛅ ฝนปรอย',
                      desc: '4.5mm (45%)',
                      presetKey: 'cloudy',
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniPresetBtn(
                      context,
                      sensor,
                      label: '🌧️ ฝนหนัก',
                      desc: '25mm (75%)',
                      presetKey: 'heavy_rain',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniPresetBtn(
                      context,
                      sensor,
                      label: '⛈️ พายุวิกฤต',
                      desc: '55mm (95%)',
                      presetKey: 'storm_critical',
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions Row: Customize / Reset
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('⚙️ ปรับแต่งสไลเดอร์', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  onPressed: () => showMockWeatherDialog(context),
                ),
              ),
              if (isMock) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('คืนค่า API สด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    onPressed: () {
                      sensor.disableMockWeather();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('คืนค่าสภาพอากาศจริง (Open-Meteo) เรียบร้อยแล้ว'),
                          backgroundColor: Colors.black87,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPresetBtn(
    BuildContext context,
    SensorProvider sensor, {
    required String label,
    required String desc,
    required String presetKey,
    required Color color,
  }) {
    final bool isCurrent = sensor.isMockWeatherEnabled &&
        (WeatherService.presets[presetKey]?['prob30'] == sensor.mockWeatherData?['prob30']);

    return InkWell(
      onTap: () {
        sensor.setMockWeatherPreset(presetKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปิดใช้งานสภาวะจำลอง: $label สำเร็จ!'),
            backgroundColor: Colors.grey[900],
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isCurrent ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent ? color : color.withValues(alpha: 0.3),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? color : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                desc,
                style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
