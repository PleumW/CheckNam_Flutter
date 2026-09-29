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
            Text(
              'กราฟสถิติระดับน้ำ (${sensor.currentDevice?.name ?? "อุปกรณ์"})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildCorrelationChart(context),
            ),
            const SizedBox(height: 20),
            // Smart Prediction Card
            _buildSmartPredictionCard(context, sensor),
            const SizedBox(height: 14),
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('ประวัติการแจ้งเตือนล่าสุด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            if (sensor.alertHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('ยังไม่มีประวัติการแจ้งเตือน', style: TextStyle(color: Colors.grey)),
              )
            else
              ...sensor.alertHistory.map((alert) {
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
              maxY: 200,
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
                    getTitlesWidget: (value, meta) {
                      final int idx = value.toInt();
                      String text = '';
                      if (_selectedRange == '24h') {
                        final h24 = sensor.history24h;
                        final step = (h24.length / 5).ceil().clamp(1, 10);
                        if (idx % step == 0 && idx < h24.length) {
                          final item = h24[idx];
                          if (item['timestamp'] != null) {
                            final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
                            text = '${dt.hour.toString().padLeft(2, '0')}:00';
                          } else {
                            text = '$idx:00';
                          }
                        }
                      } else if (_selectedRange == '7 Days') {
                        final h7d = sensor.history7d;
                        final step = (h7d.length / 7).ceil().clamp(1, 10);
                        if (idx % step == 0 && idx < h7d.length) {
                          final item = h7d[idx];
                          if (item['timestamp'] != null) {
                            final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp']);
                            const dayNames = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
                            text = dayNames[(dt.weekday - 1) % 7];
                          } else {
                            const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
                            if (idx < days.length) text = days[idx];
                          }
                        }
                      } else if (_selectedRange == 'Live') {
                        if (idx % 5 == 0) {
                          text = '${idx}s';
                        }
                      }
                      if (text.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 50,
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
                        final dt = DateTime.fromMillisecondsSinceEpoch(sensor.history24h[idx]['timestamp']);
                        timeLabel = ' (${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.)';
                      } else if (_selectedRange == '7 Days' && idx < sensor.history7d.length) {
                        final dt = DateTime.fromMillisecondsSinceEpoch(sensor.history7d[idx]['timestamp']);
                        timeLabel = ' (${dt.day}/${dt.month})';
                      }
                      return LineTooltipItem(
                        'ระดับน้ำ: ${spot.y.toStringAsFixed(1)} ซม.$timeLabel',
                        const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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

  Widget _buildSmartPredictionCard(BuildContext context, SensorProvider sensor) {
    final dev = sensor.currentDevice;
    if (dev == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dev.trendColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dev.trendColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, color: dev.trendColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('การวิเคราะห์ & คาดการณ์แนวโน้ม (Smart Forecast)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      dev.trendStatusText,
                      style: TextStyle(fontSize: 11.5, color: dev.trendColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPredictMetric(
                  label: 'ความเร็วการขึ้น/ลง',
                  value: '${dev.risingSpeed >= 0 ? '+' : ''}${dev.risingSpeed.toStringAsFixed(1)} ซม./ชม.',
                  icon: dev.trendIcon,
                  color: dev.trendColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPredictMetric(
                  label: 'ระดับแบตเตอรี่',
                  value: '${dev.batteryPercent}% (${dev.batteryVoltage.toStringAsFixed(1)}V)',
                  icon: dev.batteryIcon,
                  color: dev.batteryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dev.trendColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: dev.trendColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dev.estimatedTimeToDangerText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: dev.trendColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictMetric({required String label, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
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

