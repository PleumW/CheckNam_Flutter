import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/sensor_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedRange = 'Live';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sensor = context.read<SensorProvider>();
      if (sensor.currentDevice != null) {
        sensor.fetchDeviceHistory(sensor.currentDevice!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สถิติ & ประวัติ', style: TextStyle(fontSize: 18)),
            Row(
              children: [
                const Text('อุปกรณ์: ', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: sensor.selectedDeviceId,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 16),
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        context.read<SensorProvider>().selectDevice(newValue);
                      }
                    },
                    items: sensor.devices.values.map((device) {
                      return DropdownMenuItem<String>(
                        value: device.id,
                        child: Text(device.name),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sensor.isDeviceOnline
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sensor.isDeviceOnline
                    ? Colors.green.withValues(alpha: 0.35)
                    : Colors.orange.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sensors_rounded,
                  color: sensor.isDeviceOnline ? Colors.green : Colors.orange,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  sensor.isDeviceOnline ? 'บันทึก 24/7 อัตโนมัติ' : 'รอเชื่อมต่อ 24/7',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sensor.isDeviceOnline ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'ส่งออกรายงานสรุป',
            onPressed: () => _showExportDialog(context, sensor),
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 24/7 Auto-Logging Status Card
            _buildAutoLoggingStatusCard(context, sensor),
            const SizedBox(height: 16),
            // Chart Range Buttons
            Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabButton('Live'),
                  _buildTabButton('24h'),
                  _buildTabButton('7 Days'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'กราฟสถิติระดับน้ำ (${sensor.currentDevice?.name ?? "อุปกรณ์"})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.green, size: 8),
                      SizedBox(width: 5),
                      Text(
                        'บันทึก 24/7 จากอุปกรณ์',
                        style: TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildCorrelationChart(context),
            ),
            const SizedBox(height: 20),
            // Export Report Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('📄 ส่งออกรายงานสรุปประจำวัน (Export Report)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onPressed: () => _showExportDialog(context, sensor),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ประวัติการแจ้งเตือนล่าสุด',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey),
                ),
                if (sensor.alertHistory.isNotEmpty)
                  Text(
                    'แสดง ${sensor.alertHistory.take(5).length} อันดับล่าสุด',
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (sensor.alertHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('ยังไม่มีประวัติการแจ้งเตือน', style: TextStyle(color: Colors.grey)),
              )
            else
              ...sensor.alertHistory.take(5).map((alert) {
                IconData icon;
                Color color;
                switch (alert.type) {
                  case 'leakage':
                    icon = Icons.bolt;
                    color = Colors.red;
                    break;
                  case 'danger':
                    icon = Icons.error_outline;
                    color = Colors.red;
                    break;
                  case 'early_critical':
                    icon = Icons.warning_rounded;
                    color = Colors.deepOrange;
                    break;
                  case 'early_warning':
                    icon = Icons.speed_rounded;
                    color = Colors.orange;
                    break;
                  case 'warning':
                    icon = Icons.warning_amber_rounded;
                    color = Colors.orange;
                    break;
                  default:
                    icon = Icons.info_outline;
                    color = Colors.blue;
                }
                final timeStr = '${alert.time.hour.toString().padLeft(2, '0')}:${alert.time.minute.toString().padLeft(2, '0')}';
                return _buildHistoryItem(timeStr, alert.title, alert.subtitle, icon, color);
              }),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }



  Widget _buildTabButton(String title) {
    final isSelected = _selectedRange == title;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRange = title);
        final sensor = context.read<SensorProvider>();
        if (title != 'Live' && sensor.currentDevice != null) {
          sensor.fetchDeviceHistory(sensor.currentDevice!.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHistoryItem(String time, String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationChart(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    List<FlSpot> waterLevelSpots = [];
    double maxX = 20;

    if (_selectedRange == 'Live') {
      waterLevelSpots = sensor.waterLevelHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
      maxX = 20;
    } else if (_selectedRange == '24h') {
      final h24 = sensor.history24h;
      if (h24.isNotEmpty) {
        waterLevelSpots = h24.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['waterLevel'] ?? 0.0).toDouble())).toList();
        maxX = (h24.length - 1).toDouble();
      }
      if (maxX < 1) maxX = 1;
    } else if (_selectedRange == '7 Days') {
      final h7d = sensor.history7d;
      if (h7d.isNotEmpty) {
        waterLevelSpots = h7d.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['waterLevel'] ?? 0.0).toDouble())).toList();
        maxX = (h7d.length - 1).toDouble();
      }
      if (maxX < 1) maxX = 1;
    }

    if (sensor.isLoadingHistory && waterLevelSpots.isEmpty && _selectedRange != 'Live') {
      return const Center(child: CircularProgressIndicator());
    }

    if (waterLevelSpots.isEmpty) {
      waterLevelSpots.add(FlSpot(0, sensor.waterLevel));
    }

    double maxY = 200.0;
    if (waterLevelSpots.isNotEmpty) {
      final highest = waterLevelSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (highest > 160) {
        maxY = ((highest * 1.25) / 50).ceil() * 50.0;
      }
    }

    // กำหนดจำนวน Tick และ Interval บนแกนเวลาให้ไม่ซ้ำซ้อน
    final int totalTicks;
    final double bottomInterval;
    if (_selectedRange == '24h') {
      totalTicks = 4;
      bottomInterval = (maxX / totalTicks).clamp(1.0, double.infinity);
    } else if (_selectedRange == '7 Days') {
      totalTicks = 6;
      bottomInterval = (maxX / totalTicks).clamp(1.0, double.infinity);
    } else {
      totalTicks = 4;
      bottomInterval = 5.0;
    }

    String getBottomTitle(double value) {
      final double rawT = value / bottomInterval;
      final int t = rawT.round();
      if ((rawT - t).abs() > 0.08 || t < 0 || t > totalTicks) {
        return '';
      }

      if (_selectedRange == 'Live') {
        if (t == totalTicks) return 'ล่าสุด';
        final int secsAgo = (totalTicks - t) * 5;
        return '-${secsAgo}s';
      }

      if (_selectedRange == '24h') {
        final h24 = sensor.history24h;
        if (h24.isEmpty) return '';
        final int idx = (t * (h24.length - 1) / totalTicks).round().clamp(0, h24.length - 1);
        final item = h24[idx];
        if (item['timestamp'] != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
          final now = DateTime.now();
          final firstTs = h24.first['timestamp'] ?? 0;
          final lastTs = h24.last['timestamp'] ?? 0;
          final firstDt = DateTime.fromMillisecondsSinceEpoch(firstTs);
          final lastDt = DateTime.fromMillisecondsSinceEpoch(lastTs);
          final bool isShortDuration = lastDt.difference(firstDt).inHours.abs() < 12;

          if (isShortDuration) {
            // ช่วงเวลาสั้น ให้แสดงชั่วโมง:นาที เพื่อไม่ให้เวลาซ้ำกัน
            return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } else {
            // ข้อมูลรอบ 24 ชั่วโมง: แยกแยะระหว่างเมื่อวานกับวันนี้เพื่อไม่ให้ซ้ำกัน
            if (t == totalTicks) {
              return 'วันนี้ ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } else if (dt.day != now.day) {
              return 'วาน ${dt.hour.toString().padLeft(2, '0')}:00';
            } else {
              return '${dt.hour.toString().padLeft(2, '0')}:00';
            }
          }
        }
        return t == totalTicks ? 'ปัจจุบัน' : '-${(totalTicks - t) * 6}ชม.';
      }

      if (_selectedRange == '7 Days') {
        final h7d = sensor.history7d;
        if (h7d.isEmpty) return '';
        final int idx = (t * (h7d.length - 1) / totalTicks).round().clamp(0, h7d.length - 1);
        final item = h7d[idx];
        if (item['timestamp'] != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
          final now = DateTime.now();
          if (t == totalTicks || (dt.day == now.day && dt.month == now.month)) {
            return 'วันนี้';
          }
          const dayNames = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
          final dayName = dayNames[(dt.weekday - 1) % 7];
          // แสดงชื่อวันคู่กับวันที่ เพื่อการันตีว่าชื่อวันและวันที่ไม่มีทางซ้ำกันใน 7 วัน
          return '$dayName ${dt.day}';
        }
        return t == totalTicks ? 'วันนี้' : '-${totalTicks - t}วัน';
      }

      return '';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'ระดับน้ำ (ซม.)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            if (sensor.isLoadingHistory && _selectedRange != 'Live') ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              minX: 0,
              maxX: maxX,
              lineBarsData: [
                LineChartBarData(
                  spots: waterLevelSpots,
                  color: Colors.blue,
                  isCurved: true,
                  barWidth: 3.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.withValues(alpha: 0.35),
                        Colors.blue.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  left: BorderSide(color: Colors.white24, width: 1),
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: bottomInterval,
                    getTitlesWidget: (value, meta) {
                      final text = getBottomTitle(value);
                      if (text.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          text,
                          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (maxY / 4).clamp(20.0, 100.0),
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10));
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final int idx = spot.x.toInt();
                      String timeLabel = '';
                      if (_selectedRange == '24h' && idx < sensor.history24h.length) {
                        final ts = sensor.history24h[idx]['timestamp'];
                        if (ts != null) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                          timeLabel = '\nเวลา ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น. (${dt.day}/${dt.month})';
                        }
                      } else if (_selectedRange == '7 Days' && idx < sensor.history7d.length) {
                        final ts = sensor.history7d[idx]['timestamp'];
                        if (ts != null) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                          const dayNames = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
                          final dayName = dayNames[(dt.weekday - 1) % 7];
                          timeLabel = '\n$dayNameที่ ${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
                        }
                      } else if (_selectedRange == 'Live') {
                        timeLabel = ' (${idx}s)';
                      }
                      return LineTooltipItem(
                        'ระดับน้ำ: ${spot.y.toStringAsFixed(1)} ซม.$timeLabel',
                        const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
            duration: _selectedRange == 'Live' ? const Duration(milliseconds: 300) : Duration.zero,
            curve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }



  Widget _buildAutoLoggingStatusCard(BuildContext context, SensorProvider sensor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dev = sensor.currentDevice;
    final bool isOnline = dev?.isDeviceOnline ?? false;
    final int count24h = sensor.history24h.length;
    final int count7d = sensor.history7d.length;

    // หาเวลาที่บันทึกจุดล่าสุด
    String lastRecordTimeStr = 'กำลังรับข้อมูล...';
    if (sensor.history24h.isNotEmpty) {
      final lastTs = sensor.history24h.last['timestamp'];
      if (lastTs is num) {
        final dt = DateTime.fromMillisecondsSinceEpoch(lastTs.toInt());
        lastRecordTimeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
      }
    } else if (dev?.lastDataReceived != null) {
      final dt = dev!.lastDataReceived!;
      lastRecordTimeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? Colors.green.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.black12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (isOnline ? Colors.green : Colors.blueAccent).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_sync_rounded,
                      color: isOnline ? Colors.green : Colors.blueAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'บันทึกสถิติ 24/7 อัตโนมัติจากอุปกรณ์',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Text(
                        'บันทึกผ่านเซนเซอร์ตลอดเวลาโดยไม่ต้องกดบันทึกเอง',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOnline ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'ออนไลน์ 24/7' : 'ออฟไลน์',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAutoLogStatItem(
                  label: 'จุดบันทึก 24 ชม.',
                  value: '$count24h จุด',
                  icon: Icons.history_toggle_off_rounded,
                  color: Colors.blueAccent,
                ),
                Container(width: 1, height: 26, color: isDark ? Colors.white12 : Colors.grey.shade300),
                _buildAutoLogStatItem(
                  label: 'สถิติ 7 วัน',
                  value: '$count7d จุด',
                  icon: Icons.calendar_view_week_rounded,
                  color: Colors.purpleAccent,
                ),
                Container(width: 1, height: 26, color: isDark ? Colors.white12 : Colors.grey.shade300),
                _buildAutoLogStatItem(
                  label: 'บันทึกล่าสุด',
                  value: lastRecordTimeStr,
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoLogStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showExportDialog(BuildContext context, SensorProvider sensor) {
    final reportText = sensor.generateDailySummaryReport(sensor.selectedDeviceId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('รายงานสรุปสถานการณ์', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                reportText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('คัดลอก'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('คัดลอกรายงานลงคลิปบอร์ดแล้ว')),
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('แชร์รายงาน'),
            onPressed: () {
              SharePlus.instance.share(ShareParams(text: reportText, subject: 'รายงานสรุปสถานการณ์น้ำ IoT'));
            },
          ),
        ],
      ),
    );
  }
}

