import 'package:flutter/material.dart';

class DeviceManagementScreen extends StatelessWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการอุปกรณ์ IoT'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('อุปกรณ์ที่เชื่อมต่อ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildDeviceCard(
              context,
              name: 'NodeMCU - เซ็นเซอร์น้ำท่วม',
              status: 'ออนไลน์',
              ip: '192.168.1.104',
              wifi: '85%',
              battery: '100% (ไฟบ้าน)',
              lastUpdate: 'เมื่อสักครู่',
              isOnline: true,
            ),
            const SizedBox(height: 16),
            _buildDeviceCard(
              context,
              name: 'ESP32 - เซ็นเซอร์กระแสไฟฟ้า',
              status: 'ออฟไลน์',
              ip: '-',
              wifi: '-',
              battery: '0%',
              lastUpdate: 'เมื่อ 2 ชั่วโมงที่แล้ว',
              isOnline: false,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'การเพิ่มอุปกรณ์ใหม่เป็นระบบอัตโนมัติ (Auto-Discovery): เพียงโปรแกรมบอร์ด ESP ให้ส่งข้อมูลเข้า Firebase ตัวอุปกรณ์จะปรากฏในระบบทันที',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, {
    required String name,
    required String status,
    required String ip,
    required String wifi,
    required String battery,
    required String lastUpdate,
    required bool isOnline,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOnline ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.memory, color: isOnline ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildInfoRow(Icons.wifi, 'Wi-Fi Signal', wifi),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.battery_charging_full, 'Battery', battery),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.network_check, 'IP Address', ip),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.access_time, 'Last Update', lastUpdate),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('ลบอุปกรณ์'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('ตั้งค่าบอร์ด'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      ],
    );
  }
}
