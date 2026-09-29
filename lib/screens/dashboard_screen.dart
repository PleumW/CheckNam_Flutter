import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wave/wave.dart';
import 'package:latlong2/latlong.dart';

import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_service.dart';
import '../providers/location_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/sos_emergency_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isEditingLayout = false;

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => Navigator.pushNamed(context, '/simulator'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sensor.currentDevice?.name ?? 'ระบบเฝ้าระวังความปลอดภัย', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('ระบบเฝ้าระวังความปลอดภัย', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final bool isOnline = sensor.currentDevice?.isDeviceOnline ?? true;
                        final Color statusColor = isOnline ? Colors.green : Colors.redAccent;
                        final String statusText = isOnline ? 'ออนไลน์' : 'ออฟไลน์';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(isOnline ? Icons.circle : Icons.error_outline_rounded, color: statusColor, size: 8),
                              const SizedBox(width: 4),
                              Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (sensor.currentDevice?.signalColor ?? Colors.green).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.signal_cellular_alt_rounded, color: sensor.currentDevice?.signalColor ?? Colors.green, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'เน็ต ${sensor.currentDevice?.signalBars ?? 4}/4 ขีด',
                            style: TextStyle(color: sensor.currentDevice?.signalColor ?? Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (context) {
                        final dev = sensor.currentDevice;
                        final int batt = dev?.batteryPercent ?? 85;
                        final Color bColor = dev?.batteryColor ?? Colors.green;
                        final IconData bIcon = dev?.batteryIcon ?? Icons.battery_full_rounded;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(bIcon, color: bColor, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                'แบต $batt%',
                                style: TextStyle(color: bColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.pushReplacementNamed(context, '/map'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.map, color: Colors.blue, size: 12),
                            SizedBox(width: 4),
                            Text('พิกัดอุปกรณ์', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
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
        actions: [
          IconButton(
            icon: Icon(_isEditingLayout ? Icons.check_circle_rounded : Icons.tune_rounded),
            color: _isEditingLayout ? Colors.greenAccent : null,
            tooltip: _isEditingLayout ? 'เสร็จสิ้นการปรับแต่ง' : 'ปรับแต่งแดชบอร์ด',
            onPressed: () {
              setState(() {
                _isEditingLayout = !_isEditingLayout;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.pushNamed(context, '/simulator'),
            tooltip: 'IoT Simulator (Developer)',
          )
        ],
      ),
      body: Column(
        children: [
          if (_isEditingLayout)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'แตะ ↕️ ย่อ/ขยาย หรือลาก ☰ เพื่อสลับตำแหน่งการ์ด',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.read<SettingsProvider>().resetDashboardLayout(),
                    icon: const Icon(Icons.restore_rounded, size: 14, color: Colors.orange),
                    label: const Text('รีเซ็ต', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16.0),
              buildDefaultDragHandles: false,
              itemCount: settings.dashboardWidgets.length,
              onReorder: (oldIndex, newIndex) {
                context.read<SettingsProvider>().reorderDashboardWidgets(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final config = settings.dashboardWidgets[index];
                if (!_isEditingLayout && !config.isVisible) {
                  return SizedBox.shrink(key: ValueKey(config.id));
                }
                return _buildWidgetWrapper(context, config, index, sensor, settings);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_sos_btn',
        onPressed: () => SosEmergencyModal.show(context),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
        label: const Text('ขอความช่วยเหลือ SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildWidgetWrapper(
    BuildContext context,
    DashboardWidgetConfig config,
    int index,
    SensorProvider sensor,
    SettingsProvider settings,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget childWidget = _getWidgetById(context, config.id, sensor, config.sizeMode);

    final String sizeLabel = config.sizeMode == WidgetSizeMode.compact ? 'กะทัดรัด' : 'ขนาดเต็ม';
    final IconData sizeIcon = config.sizeMode == WidgetSizeMode.compact ? Icons.compress_rounded : Icons.aspect_ratio_rounded;

    return Container(
      key: ValueKey(config.id),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: _isEditingLayout
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: config.isVisible ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              )
            : null,
        child: Column(
          children: [
            if (_isEditingLayout)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(config.icon, size: 18, color: config.isVisible ? Colors.blueAccent : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        config.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: config.isVisible ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => settings.cycleWidgetSizeMode(config.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(sizeIcon, size: 14, color: Colors.blueAccent),
                            const SizedBox(width: 4),
                            Text(
                              sizeLabel,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        config.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 18,
                        color: config.isVisible ? Colors.green : Colors.grey,
                      ),
                      tooltip: config.isVisible ? 'ซ่อนกล่องนี้' : 'แสดงกล่องนี้',
                      onPressed: () => settings.toggleWidgetVisibility(config.id),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.drag_handle_rounded, color: Colors.blueAccent, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            if (config.isVisible)
              childWidget
            else if (_isEditingLayout)
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Text(
                  'กล่องนี้ถูกซ่อนอยู่ (กด 👁️ เพื่อแสดงผลอีกครั้ง)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getWidgetById(BuildContext context, String id, SensorProvider sensor, WidgetSizeMode sizeMode) {
    switch (id) {
      case 'weather_header':
        return _buildWeatherCard(context, sizeMode: sizeMode);
      case 'risk_distance':
        return _buildPersonalRiskDistanceCard(context, sensor, sizeMode: sizeMode);
      case 'status':
        return _buildStatusCard(context, sensor, sizeMode: sizeMode);
      case 'water_level':
        return _buildAnimatedWaterLevelCard(context, sensor, sizeMode: sizeMode);
      case 'electricity':
        return _buildElectricityCard(context, sensor, sizeMode: sizeMode);
      case 'weather_status':
        return _buildWeatherStatusCard(context, sensor, sizeMode: sizeMode);
      case 'water_speed':
        return _buildWaterRiseSpeedCard(context, sensor, sizeMode: sizeMode);
      case 'rain_forecast':
        return _buildRainForecastPreviewCard(context, sensor, sizeMode: sizeMode);
      case 'device_signal':
        return _buildDeviceSignalCard(context, sensor, sizeMode: sizeMode);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWeatherCard(BuildContext context, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final location = context.watch<LocationProvider>();
    final lat = location.currentPosition?.latitude ?? 13.7563;
    final lng = location.currentPosition?.longitude ?? 100.5018;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: WeatherService.fetchWeather(lat, lng),
      builder: (context, snapshot) {
        final Map<String, dynamic> weather = (snapshot.hasData && snapshot.data!.isNotEmpty)
            ? snapshot.data!
            : {
                'temperature': 29,
                'description': 'กำลังอัปเดตสภาพอากาศ...',
                'icon': '🌤️',
                'precipitation': 0.0,
                'prob30': 20,
                'prob60': 30,
                'prob90': 15,
              };

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final precip = (weather['precipitation'] ?? 0.0) as num;
            context.read<SensorProvider>().updateRainfallFromWeatherApi(
              precipitation: precip.toDouble(),
              description: weather['description'] ?? 'ปกติ',
              prob30: (weather['prob30'] ?? 10) as int,
            );
          });
        }

        final double precipVal = ((weather['precipitation'] ?? 0.0) as num).toDouble();

        if (sizeMode == WidgetSizeMode.compact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFF0284C7), const Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(weather['icon'], style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      weather['description'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  '${weather['temperature']} °C  •  💧 ${precipVal.toStringAsFixed(1)} มม.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E3A8A)]
                  : [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(weather['icon'], style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'สภาพอากาศ ตำแหน่งปัจจุบัน',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            weather['description'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.water_drop, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'ฝน ${precipVal.toStringAsFixed(1)} มม.',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
              const SizedBox(width: 10),
              Text(
                '${weather['temperature']}°C',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStatusCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    Color bgColor;
    Color fgColor;
    IconData icon;

    if (sensor.isElectricalLeakage) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      fgColor = Colors.red;
      icon = Icons.bolt;
    } else if (sensor.floodWarningLevel == FloodWarningLevel.danger) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      fgColor = Colors.red;
      icon = Icons.warning;
    } else if (sensor.floodWarningLevel == FloodWarningLevel.warning) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      fgColor = Colors.orange;
      icon = Icons.warning_amber;
    } else {
      bgColor = Colors.green.withValues(alpha: 0.15);
      fgColor = Colors.green;
      icon = Icons.gpp_good;
    }

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    return GestureDetector(
      onTap: () {
        final auth = context.read<AuthProvider>();
        if (!auth.isAuthenticated || auth.isGuest || auth.role == 'guest') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('จำกัดสิทธิ์การใช้งาน'),
              content: const Text('คุณต้องเข้าสู่ระบบเพื่อรับการแจ้งเตือนและดูรายละเอียดภัยพิบัติ'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ไว้คราวหลัง'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await context.read<AuthProvider>().signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    }
                  },
                  child: const Text('เข้าสู่ระบบ'),
                ),
              ],
            ),
          );
          return;
        }

        if (sensor.isElectricalLeakage) {
          Navigator.pushNamed(context, '/alert_leakage');
        } else if (sensor.isFloodDanger) {
          Navigator.pushNamed(context, '/alert_flood');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 12.0 : 24.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fgColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(icon, key: ValueKey(icon), size: isCompact ? 24 : 40, color: fgColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 500),
                style: Theme.of(context).textTheme.displayMedium!.copyWith(
                  color: fgColor,
                  fontSize: isCompact ? 16 : 24,
                  fontWeight: FontWeight.bold,
                ),
                child: Text('สถานะ: ${sensor.systemStatus}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWaterLevelCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    double fillPercent = sensor.waterLevel / 120.0; // Max 120 cm for visual scale
    if (fillPercent > 1.0) fillPercent = 1.0;
    double waveHeight = 1.0 - fillPercent;
    
    Color waveColor;
    Color waveColor2;
    Color statusColor;
    String statusText;

    if (sensor.floodWarningLevel == FloodWarningLevel.danger) {
      waveColor = Colors.red.withValues(alpha: 0.3);
      waveColor2 = Colors.red.withValues(alpha: 0.6);
      statusColor = Colors.red;
      statusText = 'วิกฤต';
    } else if (sensor.floodWarningLevel == FloodWarningLevel.warning) {
      waveColor = Colors.orange.withValues(alpha: 0.3);
      waveColor2 = Colors.orange.withValues(alpha: 0.6);
      statusColor = Colors.orange;
      statusText = 'เฝ้าระวัง';
    } else {
      waveColor = Colors.blue.withValues(alpha: 0.3);
      waveColor2 = Colors.blue.withValues(alpha: 0.6);
      statusColor = Colors.green;
      statusText = 'ปกติ';
    }

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        height: isCompact ? 75 : 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: WaveWidget(
                config: CustomConfig(
                  colors: [waveColor, waveColor2],
                  durations: [5000, 4000],
                  heightPercentages: [waveHeight.clamp(0.0, 1.0), (waveHeight + 0.05).clamp(0.0, 1.0)],
                ),
                backgroundColor: Colors.transparent,
                size: const Size(double.infinity, double.infinity),
                waveAmplitude: 0,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isCompact ? 12.0 : 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: EdgeInsets.all(isCompact ? 6 : 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.water_drop, color: statusColor, size: isCompact ? 20 : 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('ระดับน้ำ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: isCompact ? 11 : 14)),
                              if (!isCompact) const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 500),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 13 : 16,
                                ),
                                child: Text(statusText, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${sensor.waterLevel.toInt()}',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: isCompact ? 28 : 48, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text('ซม.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: isCompact ? 13 : 16)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElectricityCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    Color leakColor = sensor.isElectricalLeakage ? Colors.red : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87);
    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sensor.isElectricalLeakage ? Colors.red.withValues(alpha: 0.5) : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (sensor.isElectricalLeakage ? Colors.red : Colors.green).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, color: sensor.isElectricalLeakage ? Colors.red : Colors.green, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('กระแสไฟฟ้า: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text(
              sensor.isElectricalLeakage ? 'รั่วไหล (อันตราย!)' : 'ปกติ (ปลอดภัย)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: leakColor),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sensor.isElectricalLeakage ? Colors.red.withValues(alpha: 0.5) : Colors.transparent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 8),
              Text('กระแสไฟฟ้า', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 500),
            style: Theme.of(context).textTheme.displayMedium!.copyWith(
              color: leakColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            child: Text(sensor.isElectricalLeakage ? 'รั่วไหล' : 'ปกติ'),
          ),
          const SizedBox(height: 4),
          Text(
            sensor.isElectricalLeakage ? 'ตรวจพบอันตราย' : 'ปลอดภัย ไร้ไฟรั่ว',
            style: TextStyle(
              fontSize: 12,
              color: sensor.isElectricalLeakage ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStatusCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final bool isHeavy = sensor.isRainingHeavy;
    Color statusColor = isHeavy ? Colors.orange : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87);
    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isHeavy ? Colors.orange.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isHeavy ? Colors.orange.withValues(alpha: 0.5) : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud, color: isHeavy ? Colors.orange : Colors.blue, size: 18),
            const SizedBox(width: 8),
            Text('สภาพอากาศ: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(
              isHeavy ? 'ฝนตกหนัก' : (sensor.rainfall > 0 ? 'มีฝนตก' : 'ปกติ'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
            ),
            const Spacer(),
            Text('ฝน ${sensor.rainfall.toStringAsFixed(1)} มม.', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isHeavy ? Colors.orange.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHeavy ? Colors.orange.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
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
                  color: (isHeavy ? Colors.orange : Colors.blue).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud, color: isHeavy ? Colors.orange : Colors.blue, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'สภาพอากาศ (Weather API)', 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 500),
            style: Theme.of(context).textTheme.displayMedium!.copyWith(
              color: statusColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            child: Text(isHeavy ? 'ฝนตกหนัก' : (sensor.rainfall > 0 ? 'มีฝนตก' : 'ปกติ')),
          ),
          const SizedBox(height: 4),
          Text(
            'ปริมาณฝน: ${sensor.rainfall.toStringAsFixed(1)} มม. (อุตุนิยมวิทยา)',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterRiseSpeedCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final bool isFast = sensor.risingSpeed > 10.0;
    final bool isRising = sensor.risingSpeed > 0;
    
    Color statusColor;
    String statusDesc;
    IconData statusIcon;

    if (isFast) {
      statusColor = Colors.orange;
      statusDesc = 'น้ำขึ้นเร็ว';
      statusIcon = Icons.trending_up;
    } else if (isRising) {
      statusColor = Colors.blue;
      statusDesc = 'น้ำกำลังค่อยๆ สูงขึ้น';
      statusIcon = Icons.trending_up;
    } else if (sensor.risingSpeed < 0) {
      statusColor = Colors.green;
      statusDesc = 'น้ำกำลังลดลง';
      statusIcon = Icons.trending_down;
    } else {
      statusColor = Colors.green;
      statusDesc = 'น้ำคงที่ ปกติ';
      statusIcon = Icons.trending_flat;
    }

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isFast ? Colors.orange.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 8),
            Text('ความเร็วการเพิ่มระดับน้ำ: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(
              '${sensor.risingSpeed > 0 ? '+' : ''}${sensor.risingSpeed.toStringAsFixed(1)} ซม./ชม.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isFast ? Colors.orange : statusColor),
            ),
            const Spacer(),
            Text(statusDesc, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isFast ? Colors.orange.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFast ? Colors.orange : Colors.transparent,
          width: isFast ? 1.5 : 1.0,
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
                      color: (isFast ? Colors.orange : Colors.blue).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.speed, color: isFast ? Colors.orange : Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ความเร็วการเพิ่มระดับน้ำ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (isFast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'เตือนภัยล่วงหน้า',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${sensor.risingSpeed > 0 ? '+' : ''}${sensor.risingSpeed.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: isFast ? Colors.orange : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(width: 6),
              const Text('ซม./ชม.', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const Spacer(),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    statusDesc,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (sensor.currentDevice?.trendColor ?? Colors.blue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (sensor.currentDevice?.trendColor ?? Colors.blue).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sensor.currentDevice?.trendIcon ?? Icons.trending_flat_rounded,
                  color: sensor.currentDevice?.trendColor ?? Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sensor.currentDevice?.estimatedTimeToDangerText ?? 'สถานการณ์ปกติ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: sensor.currentDevice?.trendColor ?? Colors.blue,
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

  Widget _buildPersonalRiskDistanceCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final locationProvider = context.watch<LocationProvider>();
    final userPos = locationProvider.currentPosition;
    if (userPos == null) return const SizedBox.shrink();

    final userLatLng = LatLng(userPos.latitude, userPos.longitude);
    const Distance distanceCalc = Distance();

    DeviceData? nearestRiskDevice;
    double minRiskDist = double.infinity;

    DeviceData? nearestDevice;
    double minDeviceDist = double.infinity;

    for (final device in sensor.devices.values) {
      final double dist = distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(device.lat, device.lng));
      if (dist < minDeviceDist) {
        minDeviceDist = dist;
        nearestDevice = device;
      }

      if (device.isElectricalLeakage || device.isFloodDanger || device.isFloodWarning) {
        if (dist < minRiskDist) {
          minRiskDist = dist;
          nearestRiskDevice = device;
        }
      }
    }

    final targetDevice = nearestRiskDevice ?? nearestDevice;
    if (targetDevice == null) return const SizedBox.shrink();

    final double targetDistMeters = distanceCalc.as(LengthUnit.Meter, userLatLng, LatLng(targetDevice.lat, targetDevice.lng));
    const double maxAlertRadiusMeters = 100000.0; // 100 กม.

    // Do not show risk distance card if user is further than 100 km from all stations
    if (targetDistMeters > maxAlertRadiusMeters) {
      return const SizedBox.shrink();
    }

    final String distText = targetDistMeters >= 1000 
        ? '${(targetDistMeters / 1000).toStringAsFixed(2)} กม.' 
        : '${targetDistMeters.toInt()} ม.';

    final bool isElectrical = targetDevice.isElectricalLeakage;
    final bool isFloodDanger = targetDevice.isFloodDanger;
    final bool isRisk = nearestRiskDevice != null;

    final Color accentColor = isElectrical
        ? Colors.amber
        : (isFloodDanger ? const Color(0xFFEF4444) : (isRisk ? const Color(0xFFF59E0B) : const Color(0xFF10B981)));

    final IconData statusIcon = isElectrical
        ? Icons.bolt_rounded
        : (isFloodDanger ? Icons.warning_amber_rounded : (isRisk ? Icons.error_outline_rounded : Icons.shield_rounded));

    final String statusTitle = isElectrical
        ? 'รัศมีเสี่ยงภัยไฟฟ้ารั่ว'
        : (isFloodDanger ? 'รัศมีเสี่ยงน้ำท่วมวิกฤต' : (isRisk ? 'อยู่ในรัศมีเฝ้าระวัง' : 'พิกัดของคุณอยู่ในเขตปลอดภัย'));

    final String statusSubtitle = isRisk
        ? 'สถานี ${targetDevice.name} • ห่างจากคุณเพียง $distText'
        : 'สถานีที่ใกล้ที่สุด: ${targetDevice.name} ($distText) • สภาวะปกติ';

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    return GestureDetector(
      onTap: () {
        sensor.selectDevice(targetDevice.id);
        Navigator.pushReplacementNamed(context, '/map');
      },
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isCompact ? 6 : 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: accentColor, size: isCompact ? 18 : 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 4),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRainForecastPreviewCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final location = context.watch<LocationProvider>();
    final lat = location.currentPosition?.latitude ?? 13.7563;
    final lng = location.currentPosition?.longitude ?? 100.5018;

    return FutureBuilder<Map<String, dynamic>>(
      future: WeatherService.fetchWeather(lat, lng),
      builder: (context, snapshot) {
        final data = (snapshot.hasData && snapshot.data!.isNotEmpty)
            ? snapshot.data!
            : {
                'prob30': 20,
                'prob60': 30,
                'prob90': 15,
              };
        int prob30 = data['prob30'] ?? 20;
        int prob60 = data['prob60'] ?? 30;
        int prob90 = data['prob90'] ?? 15;

        // Sync IoT sensor rain readings with weather forecast
        if (sensor.rainfall >= 40 || sensor.isRainingHeavy) {
          prob30 = 95;
          prob60 = 85;
          prob90 = 70;
        } else if (sensor.rainfall > 0) {
          prob30 = 80;
          prob60 = 65;
          prob90 = 45;
        }

        final Color cardAccent = prob30 >= 60 ? Colors.orange : Colors.blue;

        String forecastSummary;
        if (sensor.rainfall >= 40 || sensor.isRainingHeavy) {
          forecastSummary = 'ขณะนี้ฝนตกหนัก คาดว่าฝนจะตกต่อเนื่องอีก 30-60 นาที ($prob30%)';
        } else if (sensor.rainfall > 0) {
          forecastSummary = 'ขณะนี้มีฝนตกในพื้นที่ คาดว่าจะมีฝนตกต่อเนื่อง ($prob30%)';
        } else if (prob30 >= 70) {
          forecastSummary = 'มีโอกาสฝนตกหนักในอีก 30 นาทีข้างหน้า ($prob30%)';
        } else if (prob30 >= 40) {
          forecastSummary = 'คาดว่าอาจมีฝนตกปรอยๆ ใน 30-60 นาทีข้างหน้า ($prob30%)';
        } else {
          forecastSummary = 'ท้องฟ้าโปร่ง โอกาสเกิดฝนตกต่ำ ($prob30%)';
        }

        final bool isCompact = sizeMode == WidgetSizeMode.compact;

        if (isCompact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardAccent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.umbrella_rounded, color: cardAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    forecastSummary,
                    style: TextStyle(fontSize: 12, color: cardAccent, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardAccent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.umbrella_rounded, color: cardAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'พยากรณ์ฝนล่วงหน้า',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '1 ชม. ข้างหน้า',
                      style: TextStyle(color: cardAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                forecastSummary,
                style: TextStyle(
                  fontSize: 12,
                  color: cardAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildForecastStepPill(context, '30 นาที', '$prob30%', prob30 >= 50 ? Icons.thunderstorm_rounded : Icons.cloudy_snowing, cardAccent)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildForecastStepPill(context, '60 นาที', '$prob60%', prob60 >= 50 ? Icons.thunderstorm_rounded : Icons.cloud_rounded, Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildForecastStepPill(context, '90 นาที', '$prob90%', prob90 >= 50 ? Icons.cloudy_snowing : Icons.wb_sunny_rounded, Colors.teal)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForecastStepPill(BuildContext context, String time, String percent, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(percent, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeviceSignalCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final device = sensor.currentDevice;
    final int signalBars = device?.signalBars ?? 4;
    final int signalRssi = device?.signalRssi ?? -62;
    final Color signalColor = device?.signalColor ?? Colors.green;
    final String qualityText = device?.signalQualityText ?? 'ดีมาก';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: signalColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          _buildSignalBarsIndicator(signalBars, signalColor),
          const SizedBox(width: 12),
          Text(
            '$signalBars/4 ขีด',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: signalColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($signalRssi dBm)',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: signalColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              qualityText,
              style: TextStyle(
                color: signalColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBarsIndicator(int activeBars, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final bool isActive = index < activeBars;
        final double barHeight = 8.0 + (index * 6.0); // 8px, 14px, 20px, 26px
        return Container(
          width: 6,
          height: barHeight,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

