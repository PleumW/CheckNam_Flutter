import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class DeviceManagementScreen extends StatelessWidget {
  const DeviceManagementScreen({super.key});

  String _formatLastUpdate(DateTime? lastSeen, DateTime? lastReceived) {
    final dt = lastSeen ?? lastReceived;
    if (dt == null) return 'ไม่เคยเชื่อมต่อ';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'เมื่อสักครู่';
    if (diff.inSeconds < 60) return 'เมื่อ ${diff.inSeconds} วินาทีที่แล้ว';
    if (diff.inMinutes < 60) return 'เมื่อ ${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return 'เมื่อ ${diff.inHours} ชั่วโมงที่แล้ว';
    return 'เมื่อ ${diff.inDays} วันที่แล้ว';
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final devices = sensor.uniqueDeviceList;
    final String selectedId = sensor.selectedDeviceId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการอุปกรณ์ IoT'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'อุปกรณ์ที่เชื่อมต่อในระบบ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${devices.length} สถานี',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.sensors_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'ไม่พบอุปกรณ์ในระบบ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กรุณาเปิดบอร์ด ESP32/NodeMCU เพื่อส่งข้อมูล หรือคืนค่าอุปกรณ์เริ่มต้น',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (sensor.deletedDeviceIds.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => sensor.restoreAllDevices(),
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('คืนค่าอุปกรณ์เริ่มต้น'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ...devices.map((dev) {
                final bool isOnline = dev.isDeviceOnline;
                final bool isSelected = dev.id == selectedId;
                final String lastUpdate = _formatLastUpdate(dev.lastSeen, dev.lastDataReceived);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : (isOnline
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.red.withValues(alpha: 0.4)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.memory,
                                    color: isOnline ? Colors.blueAccent : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dev.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${dev.boardModel} (ID: ${dev.id})',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dev.onlineStatusText,
                                  style: TextStyle(
                                    color: dev.onlineStatusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    '● สถานีที่กำลังแสดงผล',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 28, color: Colors.white12),

                      // Wi-Fi Real Telemetry
                      _buildInfoRow(
                        dev.signalIcon,
                        'สัญญาณ Wi-Fi',
                        isOnline
                            ? '${dev.signalPercent}% (${dev.signalRssi} dBm, ${dev.signalBars}/4 ขีด)'
                            : 'ไม่มีสัญญาณ (ออฟไลน์)',
                        valueColor: dev.signalColor,
                      ),
                      if (dev.wifiSsid != null && dev.wifiSsid!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.wifi_find_rounded,
                          'Wi-Fi SSID',
                          dev.wifiSsid!,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.network_check_rounded,
                        'IP Address',
                        dev.ipAddress ?? (isOnline ? 'เชื่อมต่อผ่าน DHCP' : '-'),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.water_drop_rounded,
                        'ระดับน้ำที่อ่านได้',
                        isOnline ? '${dev.waterLevel.toStringAsFixed(1)} ซม.' : 'เซนเซอร์ไม่ส่งข้อมูล',
                        valueColor: isOnline ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.warning_amber_rounded,
                        'เกณฑ์ระดับน้ำวิกฤต',
                        '${dev.waterLevelThreshold.toStringAsFixed(0)} ซม.',
                        valueColor: Colors.orange,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.access_time_rounded,
                        'อัปเดตล่าสุด',
                        lastUpdate,
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (!isSelected)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  sensor.selectDevice(dev.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('เปลี่ยนไปแสดงผลสถานี "${dev.name}" แล้ว'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: const Text('เลือกสถานีนี้'),
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.dashboard_rounded, size: 16),
                                label: const Text('ไปยังแดชบอร์ด'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'การส่งค่า Wi-Fi และฮาร์ดแวร์จริงจากบอร์ด ESP32:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• ความแรงสัญญาณคำนวณจาก WiFi.RSSI() ในหน่วย dBm (เช่น -55 dBm = ดีมาก)\n'
                          '• หากปิดสวิตช์หรือถอดไฟเลี้ยง บอร์ดจะแสดงผล "ออฟไลน์" และสัญญาณเป็น 0 ทันทีภายใน 8 วินาที\n'
                          '• ส่งคีย์ "rssi", "ip", "ssid" เข้า Firebase /devices/<id>/ เพื่อให้อ่านค่าได้ครบถ้วน',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
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

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
