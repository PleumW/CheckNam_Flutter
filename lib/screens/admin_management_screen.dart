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
  late Stream<DatabaseEvent> _sosStream;

  @override
  void initState() {
    super.initState();
    _reportsStream = _dbRef.child('admin_reports').orderByChild('timestamp').onValue.asBroadcastStream();
    _sosStream = _dbRef.child('sos_requests').onValue.asBroadcastStream();
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
            _SosRequestsTab(
              stream: _sosStream,
              dbRef: _dbRef,
            ),
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
                              InkWell(
                                onTap: () {
                                  context.read<SensorProvider>().setDeviceOnlineStatus(device.id, !isOnline);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isOnline ? Colors.green : Colors.redAccent).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.green : Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                                        style: TextStyle(
                                          color: isOnline ? Colors.green : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
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
                        final bool isNotInstalled = !installed || statusStr == 'NOT_INSTALLED';
                        final bool isModOnline = isOnline &&
                            installed &&
                            statusStr != 'FAULT' &&
                            statusStr != 'ERROR' &&
                            statusStr != 'DISCONNECTED' &&
                            !isNotInstalled &&
                            statusStr != 'NONE';

                        IconData iconData = Icons.sensors_rounded;
                        if (entry.key.contains('ultra') || cleanName.contains('ระดับน้ำ')) {
                          iconData = Icons.water_drop_outlined;
                        } else if (entry.key.contains('current') || cleanName.contains('ไฟฟ้า')) {
                          iconData = Icons.bolt_rounded;
                        } else if (entry.key.contains('flow') || cleanName.contains('ไหล')) {
                          iconData = Icons.waves_rounded;
                        }

                        String? customText;
                        Color? customCol;
                        if (isNotInstalled) {
                          customText = 'ไม่ได้ติดตั้ง';
                          customCol = Colors.grey.shade500;
                        }

                        return _buildMinimalComponentRow(
                          context,
                          name: cleanName,
                          icon: iconData,
                          isOnline: isModOnline,
                          customStatusText: customText,
                          customColor: customCol,
                        );
                      }),
                      // ติดตั้งเซนเซอร์วัดระดับน้ำ
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.water_drop_rounded, size: 16, color: device.hasWaterLevelSensor ? Colors.blueAccent : Colors.grey),
                                const SizedBox(width: 8),
                                const Text('ติดตั้งเซนเซอร์วัดระดับน้ำ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Switch.adaptive(
                              value: device.hasWaterLevelSensor,
                              activeThumbColor: Colors.blueAccent,
                              onChanged: (val) {
                                context.read<SensorProvider>().toggleWaterLevelSensorInstalled(device.id, val);
                              },
                            ),
                          ],
                        ),
                      ),
                      // ติดตั้งเซนเซอร์วัดไฟฟ้ารั่ว
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 16, color: device.hasCurrentSensor ? Colors.blueAccent : Colors.grey),
                                const SizedBox(width: 8),
                                const Text('ติดตั้งเซนเซอร์วัดไฟฟ้ารั่ว', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Switch.adaptive(
                              value: device.hasCurrentSensor,
                              activeThumbColor: Colors.blueAccent,
                              onChanged: (val) {
                                context.read<SensorProvider>().toggleCurrentSensorInstalled(device.id, val);
                              },
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
    String? customStatusText,
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
                  customStatusText ?? (isOnline ? 'ออนไลน์' : 'ออฟไลน์'),
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
                            final postId = report['postId']?.toString();
                            if (postId != null && postId.isNotEmpty) {
                              // ลบโพสต์ออกจาก community_posts
                              await widget.dbRef.child('community_posts').child(postId).remove();

                              // ลบรายการใน admin_reports ทั้งหมดที่เชื่อมโยงกับ postId นี้ เพื่อนำสัญลักษณ์เตือนภัยออกจากแผนที่
                              try {
                                final reportsSnap = await widget.dbRef.child('admin_reports').orderByChild('postId').equalTo(postId).get();
                                if (reportsSnap.exists && reportsSnap.value is Map) {
                                  final reportsMap = reportsSnap.value as Map<dynamic, dynamic>;
                                  for (final rKey in reportsMap.keys) {
                                    await widget.dbRef.child('admin_reports').child(rKey.toString()).remove();
                                  }
                                }
                              } catch (_) {}

                              try {
                                final allSnap = await widget.dbRef.child('admin_reports').get();
                                if (allSnap.exists && allSnap.value is Map) {
                                  final allMap = allSnap.value as Map<dynamic, dynamic>;
                                  for (final entry in allMap.entries) {
                                    if (entry.value is Map && entry.value['postId']?.toString() == postId) {
                                      await widget.dbRef.child('admin_reports').child(entry.key.toString()).remove();
                                    }
                                  }
                                }
                              } catch (_) {}
                            }
                            await widget.dbRef.child('admin_reports').child(report['key'].toString()).remove();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบโพสต์และนำสัญลักษณ์เตือนภัยออกจากแผนที่เรียบร้อยแล้ว')));
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

class _SosRequestsTab extends StatefulWidget {
  final Stream<DatabaseEvent> stream;
  final DatabaseReference dbRef;

  const _SosRequestsTab({
    required this.stream,
    required this.dbRef,
  });

  @override
  State<_SosRequestsTab> createState() => _SosRequestsTabState();
}

class _SosRequestsTabState extends State<_SosRequestsTab> {
  DateTime? _selectedDate;

  String _formatDateThai(DateTime d) {
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    return '${d.day} ${months[d.month]} ${d.year + 543}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _openGoogleMapsNavigation(double lat, double lng) async {
    final Uri googleMapsAppUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final Uri googleMapsWebUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl);
      } else if (await canLaunchUrl(googleMapsWebUrl)) {
        await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open Google Maps: $e');
      try {
        await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'เลือกวันที่เพื่อดูประวัติการขอความช่วยเหลือ',
      confirmText: 'ตกลง',
      cancelText: 'ยกเลิก',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _confirmDeleteSos(BuildContext context, SosRequest req) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันลบรายการ SOS'),
        content: Text('คุณต้องการลบรายการขอความช่วยเหลือของ "${req.userName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await widget.dbRef.child('sos_requests/${req.id}').remove();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ลบรายการ SOS เรียบร้อยแล้ว')),
                );
              }
            },
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return StreamBuilder<DatabaseEvent>(
      stream: widget.stream,
      builder: (context, snapshot) {
        List<SosRequest> allRequests = [];
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final raw = snapshot.data!.snapshot.value;
          if (raw is Map) {
            raw.forEach((key, val) {
              if (val is Map) {
                try {
                  allRequests.add(SosRequest.fromJson(key.toString(), val));
                } catch (e) {
                  debugPrint('Error parsing SOS item: $e');
                }
              }
            });
          } else if (raw is List) {
            for (int i = 0; i < raw.length; i++) {
              final val = raw[i];
              if (val is Map) {
                try {
                  allRequests.add(SosRequest.fromJson(i.toString(), val));
                } catch (e) {
                  debugPrint('Error parsing SOS item in list: $e');
                }
              }
            }
          }
          allRequests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }

        // Fallback to sensor.sosRequests if stream snapshot has not yet populated
        if (allRequests.isEmpty && sensor.sosRequests.isNotEmpty) {
          allRequests = sensor.sosRequests;
        }

        final filteredRequests = _selectedDate == null
            ? allRequests
            : allRequests.where((req) => _isSameDay(req.timestamp, _selectedDate!)).toList();

        return Column(
          children: [
            // แถบเลือกวันที่และตัวกรองประวัติ SOS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // ปุ่มเลือกวันที่ดูประวัติ
                  InkWell(
                    onTap: () => _pickDate(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedDate != null
                            ? Colors.blueAccent.withValues(alpha: 0.15)
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedDate != null ? Colors.blueAccent : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: _selectedDate != null ? Colors.blueAccent : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedDate == null ? 'เลือกวันที่ดูประวัติ' : _formatDateThai(_selectedDate!),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedDate != null ? Colors.blueAccent : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chip: ทั้งหมด
                  FilterChip(
                    label: const Text('ทั้งหมด', style: TextStyle(fontSize: 11)),
                    selected: _selectedDate == null,
                    onSelected: (_) {
                      setState(() => _selectedDate = null);
                    },
                    selectedColor: Colors.blueAccent.withValues(alpha: 0.2),
                    checkmarkColor: Colors.blueAccent,
                    labelStyle: TextStyle(
                      color: _selectedDate == null ? Colors.blueAccent : Colors.grey,
                      fontWeight: _selectedDate == null ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 6),
                  // Chip: วันนี้
                  FilterChip(
                    label: const Text('วันนี้', style: TextStyle(fontSize: 11)),
                    selected: _selectedDate != null && _isSameDay(_selectedDate!, now),
                    onSelected: (_) {
                      setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
                    },
                    selectedColor: Colors.blueAccent.withValues(alpha: 0.2),
                    checkmarkColor: Colors.blueAccent,
                    labelStyle: TextStyle(
                      color: (_selectedDate != null && _isSameDay(_selectedDate!, now)) ? Colors.blueAccent : Colors.grey,
                      fontWeight: (_selectedDate != null && _isSameDay(_selectedDate!, now)) ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Spacer(),
                  // จำนวนรายการ
                  Text(
                    '${filteredRequests.length} รายการ',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            // เนื้อหารายการ SOS
            Expanded(
              child: filteredRequests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedDate == null ? Icons.health_and_safety_outlined : Icons.event_busy_rounded,
                              size: 56,
                              color: _selectedDate == null ? Colors.green.withValues(alpha: 0.5) : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedDate == null
                                  ? 'ไม่มีสัญญาณขอความช่วยเหลือในขณะนี้'
                                  : 'ไม่พบประวัติการขอความช่วยเหลือในวันที่ ${_formatDateThai(_selectedDate!)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDate == null
                                  ? 'สถานการณ์ในพื้นที่ปกติและปลอดภัย'
                                  : 'ท่านสามารถเลือกวันที่อื่น หรือกดดูประวัติทั้งหมดได้',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            if (_selectedDate != null) ...[
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _selectedDate = null);
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('ดูประวัติทั้งหมด', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final req = filteredRequests[index];
                        final bool isPending = req.status == 'pending';
                        final bool isInProgress = req.status == 'in_progress';
                        final Color statusColor = isPending ? Colors.redAccent : (isInProgress ? Colors.orange : Colors.green);
                        final String statusLabel = isPending ? 'รอดำเนินการ' : (isInProgress ? 'กำลังช่วยเหลือ' : 'ช่วยเหลือแล้ว');

                        final timeStr = '${req.timestamp.hour.toString().padLeft(2, '0')}:${req.timestamp.minute.toString().padLeft(2, '0')} น. (${req.timestamp.day}/${req.timestamp.month}/${req.timestamp.year + 543})';

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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                        tooltip: 'ลบรายการนี้',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmDeleteSos(context, req),
                                      ),
                                    ],
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
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 14, color: Colors.blueAccent),
                                        const SizedBox(width: 4),
                                        Text('พิกัด GPS: ${req.lat.toStringAsFixed(6)}, ${req.lng.toStringAsFixed(6)}', style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // ปุ่มนำทาง Google Maps
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.navigation_rounded, size: 16),
                                      label: const Text('นำทาง', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _openGoogleMapsNavigation(req.lat, req.lng),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // ปุ่มโทรหา
                                  if (req.phoneNumber.isNotEmpty) ...[
                                    Expanded(
                                      flex: 3,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green,
                                          side: const BorderSide(color: Colors.green),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.phone, size: 16),
                                        label: const Text('โทร', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final uri = Uri.parse('tel:${req.phoneNumber}');
                                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // ตัวเลือกสถานะ
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: req.status,
                                          isDense: true,
                                          isExpanded: true,
                                          items: const [
                                            DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                                            DropdownMenuItem(value: 'in_progress', child: Text('กำลังช่วยเหลือ', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
                                            DropdownMenuItem(value: 'resolved', child: Text('ช่วยเหลือแล้ว', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              widget.dbRef.child('sos_requests/${req.id}/status').set(val);
                                              sensor.updateSosStatus(req.id, val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

