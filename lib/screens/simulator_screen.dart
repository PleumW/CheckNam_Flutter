import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _waterFlowController = TextEditingController();
  final TextEditingController _rainController = TextEditingController();
  bool _leakage = false;
  bool _isOnline = true;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
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

  void _loadDeviceData() {
    if (_selectedDeviceId == null) return;
    final sensor = context.read<SensorProvider>();
    final device = sensor.devices[_selectedDeviceId];
    if (device != null) {
      _waterController.text = device.waterLevel.toStringAsFixed(1);
      _waterFlowController.text = device.waterFlow.toStringAsFixed(1);
      _rainController.text = device.rainfall.toStringAsFixed(1);
      _leakage = device.isElectricalLeakage;
      _isOnline = device.isDeviceOnline;
    }
  }

  void _sendSimulation({double? water, double? flow, double? rain, bool? leakage, bool? isOnline}) {
    if (_selectedDeviceId == null) return;

    final double waterVal = water ?? (double.tryParse(_waterController.text) ?? 15.0);
    final double flowVal = flow ?? (double.tryParse(_waterFlowController.text) ?? 5.0);
    final double rainVal = rain ?? (double.tryParse(_rainController.text) ?? 0.0);
    final bool leakageVal = leakage ?? _leakage;
    final bool onlineVal = isOnline ?? _isOnline;

    if (water != null) _waterController.text = water.toStringAsFixed(1);
    if (flow != null) _waterFlowController.text = flow.toStringAsFixed(1);
    if (rain != null) _rainController.text = rain.toStringAsFixed(1);
    if (leakage != null) setState(() => _leakage = leakage);
    if (isOnline != null) setState(() => _isOnline = isOnline);

    final sensor = context.read<SensorProvider>();
    final currentDevice = sensor.devices[_selectedDeviceId!];
    final double lat = currentDevice?.lat ?? 13.7563;
    final double lng = currentDevice?.lng ?? 100.5018;

    sensor.simulateDataFromIoT(
      deviceId: _selectedDeviceId!,
      lat: lat,
      lng: lng,
      waterLevel: waterVal,
      waterFlow: flowVal,
      isLeakage: leakageVal,
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
            Text('ส่งข้อมูลจำลองไปยัง "${currentDevice?.name ?? _selectedDeviceId}" สำเร็จ!'),
          ],
        ),
        backgroundColor: Colors.grey[900],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _waterController.dispose();
    _waterFlowController.dispose();
    _rainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final devices = sensor.devices;

    if (_selectedDeviceId == null && devices.isNotEmpty) {
      _selectedDeviceId = sensor.selectedDeviceId.isNotEmpty && devices.containsKey(sensor.selectedDeviceId)
          ? sensor.selectedDeviceId
          : devices.keys.first;
      _loadDeviceData();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Hardware Simulator'),
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
                  Icon(Icons.developer_board, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'เครื่องมือจำลองเซนเซอร์ ESP32 / IoT เพื่อทดสอบระบบแจ้งเตือน ระดับน้ำ และไฟฟ้ารั่ว',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (devices.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: devices.containsKey(_selectedDeviceId) ? _selectedDeviceId : devices.keys.first,
                decoration: const InputDecoration(
                  labelText: 'เลือกอุปกรณ์ที่ต้องการจำลองข้อมูล',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sensors),
                ),
                items: devices.values.map((device) {
                  return DropdownMenuItem(
                    value: device.id,
                    child: Text('${device.name} (ID: ${device.id})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedDeviceId = val;
                      _loadDeviceData();
                    });
                  }
                },
              )
            else
              const Text('ไม่พบรายการอุปกรณ์ในระบบ', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 16),

            TextField(
              controller: _waterController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ระดับน้ำ (ซม.)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.water),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _waterFlowController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'อัตราการไหลของน้ำ (m³/s)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.waves),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rainController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ปริมาณฝน (มม./ชม.)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grain),
              ),
            ),
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
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('จำลองกระแสไฟฟ้ารั่วไหลในน้ำ ⚡'),
              subtitle: Text(_leakage ? 'สถานะ: ตรวจพบไฟฟ้ารั่ว! (อันตราย)' : 'สถานะ: ปกติ'),
              value: _leakage,
              activeTrackColor: Colors.red,
              onChanged: (val) {
                setState(() {
                  _leakage = val;
                });
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
            const SizedBox(height: 28),
            const Text('ปุ่มทดสอบสภาวะด่วน (Quick Test Presets):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _sendSimulation(water: 15.0, flow: 5.0, rain: 0.0, leakage: false),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('ปกติ (15 ซม.)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        onPressed: () => _sendSimulation(water: 35.0, flow: 15.0, rain: 15.0, leakage: false),
                        icon: const Icon(Icons.warning_amber_rounded, size: 18),
                        label: const Text('เฝ้าระวัง (35 ซม.)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => _sendSimulation(water: 75.0, flow: 35.0, rain: 45.0, leakage: false),
                        icon: const Icon(Icons.dangerous, size: 18),
                        label: const Text('วิกฤตน้ำท่วม (75 ซม.)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], foregroundColor: Colors.amberAccent),
                        onPressed: () => _sendSimulation(water: 40.0, flow: 12.0, rain: 20.0, leakage: true),
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text('ไฟฟ้ารั่ว ⚡'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

