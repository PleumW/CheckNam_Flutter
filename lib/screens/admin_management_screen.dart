import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sensor_provider.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late Stream<DatabaseEvent> _reportsStream;

  @override
  void initState() {
    super.initState();
    _reportsStream = _dbRef.child('admin_reports').orderByChild('timestamp').onValue.asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sensor = context.watch<SensorProvider>();
    final int pendingSos = sensor.pendingSosCount;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text(
            'การจัดการระบบ (Admin)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(38),
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                tabs: [
                  const Tab(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.memory_rounded, size: 15),
                        SizedBox(width: 4),
                        Text('อุปกรณ์'),
                      ],
                    ),
                  ),
                  const Tab(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_problem_rounded, size: 15),
                        SizedBox(width: 4),
                        Text('รายงาน'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sos_rounded, size: 15, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        const Text('SOS'),
                        if (pendingSos > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingSos',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _DeviceStatusTab(
              onDeleteDevice: (id, name) => _showDeleteConfirmDialog(context, id, name),
            ),
            _ReportsTab(
              stream: _reportsStream,
              dbRef: _dbRef,
            ),
            const _SosRequestsTab(),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String deviceId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันลบอุปกรณ์'),
        content: Text('คุณต้องการลบอุปกรณ์ "$name" (ID: $deviceId) ออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await _dbRef.child('devices/$deviceId').remove();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบอุปกรณ์ $name เรียบร้อยแล้ว')));
              }
            },
            child: const Text('ลบอุปกรณ์'),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusTab extends StatefulWidget {
  final Function(String id, String name) onDeleteDevice;

  const _DeviceStatusTab({
    required this.onDeleteDevice,
  });

  @override
  State<_DeviceStatusTab> createState() => _DeviceStatusTabState();
}

class _DeviceStatusTabState extends State<_DeviceStatusTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final sensorProvider = context.watch<SensorProvider>();
    final devicesMap = sensorProvider.devices;

        if (devicesMap.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีอุปกรณ์ในระบบ', style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final devices = devicesMap.values.toList();
        int totalCount = devices.length;
        int onlineCount = devices.where((d) => d.isDeviceOnline).length;
        int offlineCount = totalCount - onlineCount;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('อุปกรณ์ทั้งหมด', '$totalCount', isDark ? Colors.white : Colors.black87),
                  Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildSummaryItem('ออนไลน์', '$onlineCount', Colors.green),
                  Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.2)),
                  _buildSummaryItem('ออฟไลน์', '$offlineCount', Colors.grey.shade500),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                const SizedBox(width: 4),
                Text(
                  'รายการอุปกรณ์',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...devices.map((device) {
              final bool isOnline = device.isDeviceOnline;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sensors_rounded,
                                    color: isOnline ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        device.id,
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isOnline ? Colors.green : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                                      style: TextStyle(
                                        color: isOnline ? Colors.green : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                                splashRadius: 18,
                                onPressed: () {
                                  widget.onDeleteDevice(device.id, device.name);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      const SizedBox(height: 12),

                      _buildMinimalComponentRow(
                        context,
                        name: 'บอร์ด ${(device.boardModel.isNotEmpty) ? device.boardModel : 'ESP32'}',
                        icon: Icons.memory_rounded,
                        isOnline: isOnline,
                      ),

                      ...device.dynamicModules.entries.map((entry) {
                        final mod = entry.value is Map ? entry.value as Map : <String, dynamic>{};
                        String rawName = mod['name']?.toString() ?? entry.key.toString();

                        String cleanName = rawName;
                        if (rawName.contains('ระดับน้ำ') || entry.key.contains('ultra')) {
                          cleanName = 'เซนเซอร์วัดระดับน้ำ';
                        } else if (rawName.contains('ไฟ') || entry.key.contains('current')) {
                          cleanName = 'เซนเซอร์วัดไฟฟ้ารั่ว';
                        } else if (rawName.contains('ไหล') || entry.key.contains('flow')) {
                          cleanName = 'เซนเซอร์วัดอัตราการไหล';
                        } else if (rawName.contains('ฝน') || entry.key.contains('rain')) {
                          cleanName = 'เซนเซอร์ตรวจวัดน้ำฝน';
                        }

                        final bool installed = mod['installed'] == true;
                        final String statusStr = (mod['status']?.toString() ?? 'OK').toUpperCase();
                        final bool isModOnline = isOnline &&
                            installed &&
                            statusStr != 'FAULT' &&
                            statusStr != 'ERROR' &&
                            statusStr != 'DISCONNECTED' &&
                            statusStr != 'NOT_INSTALLED' &&
                            statusStr != 'NONE';

                        IconData iconData = Icons.sensors_rounded;
                        if (entry.key.contains('ultra') || cleanName.contains('ระดับน้ำ')) {
                          iconData = Icons.water_drop_outlined;
                        } else if (entry.key.contains('current') || cleanName.contains('ไฟฟ้า')) {
                          iconData = Icons.bolt_rounded;
                        } else if (entry.key.contains('flow') || cleanName.contains('ไหล')) {
                          iconData = Icons.waves_rounded;
                        }

                        return _buildMinimalComponentRow(
                          context,
                          name: cleanName,
                          icon: iconData,
                          isOnline: isModOnline,
                        );
                      }),

                      _buildMinimalComponentRow(
                        context,
                        name: 'แบตเตอรี่ ${device.batteryStatusText}',
                        icon: device.batteryIcon,
                        isOnline: isOnline,
                        customColor: device.batteryColor,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.straighten_rounded, size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                Text(
                                  'ความสูงติดตั้ง: ${device.sensorHeight.toStringAsFixed(1)} ซม.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => _showCalibrationDialog(context, device),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.tune_rounded, size: 13, color: Colors.blueAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'ปรับเทียบ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
  }

  void _showCalibrationDialog(BuildContext context, DeviceData device) {
    final controller = TextEditingController(text: device.sensorHeight.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('ปรับเทียบเซนเซอร์ (${device.name})', style: const TextStyle(fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กำหนดระยะความสูงจากหัวเซนเซอร์ถึงพื้นคลอง/ถนน (ซม.) เพื่อคำนวณระดับน้ำจริง:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ความสูงติดตั้งเซนเซอร์ (ซม.)',
                suffixText: 'ซม.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () async {
              final double? newHeight = double.tryParse(controller.text.trim());
              if (newHeight != null && newHeight > 0) {
                await context.read<SensorProvider>().updateDeviceCalibration(device.id, newHeight);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('อัปเดตความสูงเซนเซอร์ ${device.name} เป็น ${newHeight.toStringAsFixed(1)} ซม. แล้ว')),
                  );
                }
              }
            },
            child: const Text('บันทึกค่า'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMinimalComponentRow(
    BuildContext context, {
    required String name,
    required IconData icon,
    required bool isOnline,
    Color? customColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statusColor = customColor ?? (isOnline ? Colors.green : Colors.grey.shade500);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isOnline ? Colors.blueAccent : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isOnline ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  final Stream<DatabaseEvent> stream;
  final DatabaseReference dbRef;

  const _ReportsTab({
    required this.stream,
    required this.dbRef,
  });

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<DatabaseEvent>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('ไม่มีรายงานแจ้งเหตุคงค้าง', style: TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          );
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final reports = data.entries.map((e) {
          final Map<dynamic, dynamic> val = (e.value is Map<dynamic, dynamic>) ? e.value as Map<dynamic, dynamic> : {};
          return {'key': e.key, ...val};
        }).toList();

        reports.sort((a, b) {
          final int tsA = (a['timestamp'] is num) ? (a['timestamp'] as num).toInt() : 0;
          final int tsB = (b['timestamp'] is num) ? (b['timestamp'] as num).toInt() : 0;
          return tsB.compareTo(tsA);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final reason = report['reason'] ?? 'ไม่มีเหตุผล';
            final reportedBy = report['reportedBy'] ?? 'Unknown';
            final int timestamp = (report['timestamp'] is num) ? (report['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch;
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final formattedDate = '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
            final postContent = report['postContent'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ผู้แจ้ง: $reportedBy', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('เหตุผล: $reason', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    if (postContent.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('เนื้อหา: $postContent', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            await widget.dbRef.child('admin_reports').child(report['key']).remove();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ละเว้นรายงานเรียบร้อยแล้ว')));
                            }
                          },
                          child: const Text('ละเว้น', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          onPressed: () async {
                            if (report['postId'] != null) {
                              await widget.dbRef.child('community_posts').child(report['postId']).remove();
                            }
                            await widget.dbRef.child('admin_reports').child(report['key']).remove();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบโพสต์สำเร็จ')));
                            }
                          },
                          child: const Text('ลบโพสต์', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SosRequestsTab extends StatelessWidget {
  const _SosRequestsTab();

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final requests = sensor.sosRequests;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.health_and_safety_outlined, size: 56, color: Colors.green.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text('ไม่มีสัญญาณขอความช่วยเหลือในขณะนี้', style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('สถานการณ์ในพื้นที่ปกติและปลอดภัย', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final bool isPending = req.status == 'pending';
        final bool isInProgress = req.status == 'in_progress';
        final Color statusColor = isPending ? Colors.redAccent : (isInProgress ? Colors.orange : Colors.green);
        final String statusLabel = isPending ? 'รอดำเนินการ' : (isInProgress ? 'กำลังช่วยเหลือ' : 'ช่วยเหลือแล้ว');

        final timeStr = '${req.timestamp.hour.toString().padLeft(2, '0')}:${req.timestamp.minute.toString().padLeft(2, '0')} น. (${req.timestamp.day}/${req.timestamp.month})';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPending ? Colors.redAccent.withValues(alpha: 0.5) : (isDark ? Colors.white10 : Colors.black12),
              width: isPending ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.sos_rounded, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('เหตุฉุกเฉิน: ${req.situation}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
                    if (req.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('รายละเอียด: ${req.note}', style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 4),
                    Text('พิกัด GPS: ${req.lat.toStringAsFixed(6)}, ${req.lng.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(req.phoneNumber.isNotEmpty ? req.phoneNumber : 'โทรหา', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: req.phoneNumber.isNotEmpty ? () async {
                        final uri = Uri.parse('tel:${req.phoneNumber}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      } : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: req.status,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: 'in_progress', child: Text('กำลังช่วยเหลือ', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: 'resolved', child: Text('ช่วยเหลือแล้ว', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            sensor.updateSosStatus(req.id, val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

