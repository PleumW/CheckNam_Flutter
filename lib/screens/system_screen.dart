import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final dev = sensor.currentDevice;
    final bool isOnline = dev?.isDeviceOnline ?? false;
    final int signalPercent = dev?.signalPercent ?? 0;
    final IconData signalIcon = dev?.signalIcon ?? Icons.wifi_off_rounded;
    final Color signalColor = dev?.signalColor ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('การจัดการระบบ', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(dev?.name ?? 'ไม่มีข้อมูลอุปกรณ์', style: const TextStyle(fontSize: 18)),
          ],
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('ระบบเฝ้าระวังความปลอดภัย', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                isOnline ? '(Online)' : '(Offline)',
                style: TextStyle(color: isOnline ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('สถานะอุปกรณ์เซนเซอร์ & ฮาร์ดแวร์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          _buildDeviceCard(
            context,
            name: dev?.boardModel ?? 'ESP32 IoT Board',
            subtitle: dev?.networkType ?? 'Wi-Fi (2.4 GHz)',
            status: isOnline ? 'Online' : 'Offline',
            percentText: isOnline ? '$signalPercent%' : '0%',
            icon: signalIcon,
            iconColor: signalColor,
            isOnline: isOnline,
          ),
          _buildDeviceCard(
            context,
            name: 'JSN-SR04T / Ultrasonic',
            subtitle: isOnline ? 'ระดับน้ำ: ${dev?.waterLevel.toStringAsFixed(1)} ซม.' : 'ออฟไลน์ (ไม่มีข้อมูล)',
            status: isOnline ? 'Connected' : 'Offline',
            percentText: isOnline ? 'OK' : 'FAULT',
            icon: Icons.water_drop_rounded,
            iconColor: isOnline ? Colors.blue : Colors.grey,
            isOnline: isOnline,
          ),
          _buildDeviceCard(
            context,
            name: 'SCT-013 Current Sensor',
            subtitle: (dev?.hasCurrentSensor ?? false)
                ? (dev?.isElectricalLeakage == true ? '⚠️ ตรวจพบไฟฟ้ารั่ว!' : 'ปกติ (กระแสไฟ 0.00A)')
                : 'ยังไม่ได้ติดตั้งเซนเซอร์',
            status: (dev?.hasCurrentSensor ?? false)
                ? (isOnline ? 'Connected' : 'Offline')
                : 'Not Installed',
            percentText: (dev?.hasCurrentSensor ?? false) ? 'OK' : 'N/A',
            icon: Icons.bolt_rounded,
            iconColor: (dev?.hasCurrentSensor ?? false)
                ? (dev?.isElectricalLeakage == true ? Colors.red : Colors.green)
                : Colors.orange,
            isOnline: isOnline && (dev?.hasCurrentSensor ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context, {
    required String name,
    required String subtitle,
    required String status,
    required String percentText,
    required IconData icon,
    required Color iconColor,
    required bool isOnline,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: CircleAvatar(
          backgroundColor: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(percentText, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 12),
                const SizedBox(width: 4),
                Text(status, style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
