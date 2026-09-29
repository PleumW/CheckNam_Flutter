import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('การจัดการระบบ', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(sensor.currentDevice?.name ?? 'ไม่มีข้อมูลอุปกรณ์', style: const TextStyle(fontSize: 18)),
          ],
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: const [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('ระบบเฝ้าระวังความปลอดภัย', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              Spacer(),
              Text('(Online)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('สถานะอุปกรณ์เซนเซอร์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          _buildDeviceCard(context, 'NodeMCU Main Board', 'อุปกรณ์ศูนย์กลางเชื่อมต่อ', 'Online', true),
          _buildDeviceCard(context, 'HC-SR04', 'เซนเซอร์วัดระดับน้ำ', 'Connected', true),
          _buildDeviceCard(context, 'SCT-013', 'เซนเซอร์วัดกระแสไฟฟ้า', 'Connected', true),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, String name, String subtitle, String status, bool isOnline) {
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
          child: Icon(Icons.memory, color: isOnline ? Colors.green : Colors.red),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('100%', style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, color: isOnline ? Colors.green : Colors.grey, size: 12),
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
