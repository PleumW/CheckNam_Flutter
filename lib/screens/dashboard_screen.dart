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
import '../services/audio_alarm_service.dart';

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
        toolbarHeight: 78,
        title: GestureDetector(
          onTap: sensor.devices.length > 1 ? () => _showDeviceSelectorBottomSheet(context, sensor) : null,
          onLongPress: () => Navigator.pushNamed(context, '/simulator'),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      sensor.currentDevice?.name ?? 'ระบบเฝ้าระวังความปลอดภัย',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sensor.devices.length > 1) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Colors.blueAccent),
                  ],
                ],
              ),
              Text(
                sensor.devices.length > 1
                    ? 'สลับสถานี (${sensor.devices.values.where((d) => d.isDeviceOnline).length}/${sensor.devices.length} ออนไลน์)'
                    : 'ระบบเฝ้าระวังความปลอดภัย',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final bool isOnline = sensor.currentDevice?.isDeviceOnline ?? false;
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
                    Builder(
                      builder: (context) {
                        final dev = sensor.currentDevice;
                        final bool isOnline = dev?.isDeviceOnline ?? false;
                        final Color sigColor = dev?.signalColor ?? Colors.grey;
                        final IconData sigIcon = dev?.signalIcon ?? Icons.wifi_off_rounded;
                        final String sigText = isOnline
                            ? 'Wi-Fi ${dev?.signalPercent ?? 0}% (${dev?.signalBars ?? 0}/4)'
                            : 'Wi-Fi ออฟไลน์';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sigColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(sigIcon, color: sigColor, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                sigText,
                                style: TextStyle(color: sigColor, fontSize: 10, fontWeight: FontWeight.bold),
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
                    const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: AudioAlarmService(),
                      builder: (context, _) {
                        final alarm = AudioAlarmService();
                        final bool isPlaying = alarm.isPlaying;
                        final bool isEnabled = alarm.isAlarmEnabled;
                        final sensor = context.watch<SensorProvider>();
                        final bool isCritical = sensor.devices.values.any((d) =>
                            d.isElectricalLeakage ||
                            d.waterLevel >= 60.0 ||
                            d.isFloodDanger ||
                            d.earlyWarningSeverity == EarlyWarningSeverity.critical);

                        final Color bgColor;
                        final Color borderColor;
                        final Color contentColor;
                        final IconData iconData;
                        final String labelText;

                        if (isPlaying) {
                          bgColor = Colors.redAccent.withValues(alpha: 0.25);
                          borderColor = Colors.redAccent;
                          contentColor = Colors.redAccent;
                          iconData = Icons.volume_up_rounded;
                          labelText = 'ไซเรนดัง (กดปิด)';
                        } else if (isEnabled) {
                          bgColor = Colors.green.withValues(alpha: 0.15);
                          borderColor = Colors.green.withValues(alpha: 0.4);
                          contentColor = Colors.greenAccent;
                          iconData = Icons.volume_up_rounded;
                          labelText = 'เปิดเสียงเตือน';
                        } else {
                          bgColor = Colors.white.withValues(alpha: 0.08);
                          borderColor = Colors.white24;
                          contentColor = Colors.grey.shade400;
                          iconData = Icons.volume_off_rounded;
                          labelText = 'ปิดเสียงเตือน';
                        }

                        return InkWell(
                          onTap: () {
                            alarm.toggleAlarm(isCurrentlyCritical: isCritical);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: borderColor,
                                width: isPlaying ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  iconData,
                                  color: contentColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  labelText,
                                  style: TextStyle(
                                    color: contentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: AudioAlarmService(),
            builder: (context, _) {
              final alarm = AudioAlarmService();
              final bool isPlaying = alarm.isPlaying;
              final bool isEnabled = alarm.isAlarmEnabled;
              final sensor = context.watch<SensorProvider>();
              final bool isCritical = sensor.devices.values.any((d) =>
                  d.isElectricalLeakage ||
                  d.waterLevel >= 60.0 ||
                  d.isFloodDanger ||
                  d.earlyWarningSeverity == EarlyWarningSeverity.critical);

              final Color bgColor;
              final Color iconColor;
              final IconData iconData;
              final String tooltip;

              if (isPlaying) {
                bgColor = Colors.redAccent.withValues(alpha: 0.25);
                iconColor = Colors.redAccent;
                iconData = Icons.volume_up_rounded;
                tooltip = 'ไซเรนเตือนภัยกำลังดัง (กดเพื่อปิดเสียง)';
              } else if (isEnabled) {
                bgColor = Colors.green.withValues(alpha: 0.15);
                iconColor = Colors.greenAccent;
                iconData = Icons.volume_up_rounded;
                tooltip = 'เปิดระบบเสียงเตือนภัยค้างไว้ (พร้อมดังเมื่อวิกฤต)';
              } else {
                bgColor = Colors.transparent;
                iconColor = Colors.grey;
                iconData = Icons.volume_off_rounded;
                tooltip = 'ปิดเสียงเตือนภัย (กดเพื่อเปิดระบบเสียง)';
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: isPlaying
                      ? Border.all(color: Colors.redAccent, width: 1.5)
                      : (isEnabled ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.0) : null),
                ),
                child: IconButton(
                  icon: Icon(
                    iconData,
                    color: iconColor,
                  ),
                  tooltip: tooltip,
                  onPressed: () {
                    alarm.toggleAlarm(isCurrentlyCritical: isCritical);
                  },
                ),
              );
            },
          ),
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
      floatingActionButton: SizedBox(
        height: 38,
        child: FloatingActionButton.extended(
          heroTag: 'dashboard_sos_btn',
          onPressed: () => SosEmergencyModal.show(context),
          backgroundColor: Colors.redAccent,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          label: const Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
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
              prob60: (weather['prob60'] ?? 20) as int,
              prob90: (weather['prob90'] ?? 15) as int,
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
                Expanded(
                  child: Row(
                    children: [
                      Text(weather['icon'], style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          weather['description'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
    } else if (sensor.floodWarningLevel == FloodWarningLevel.danger || sensor.earlyWarningSeverity == EarlyWarningSeverity.critical) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      fgColor = Colors.red;
      icon = Icons.warning_rounded;
    } else if (sensor.floodWarningLevel == FloodWarningLevel.warning || sensor.earlyWarningSeverity == EarlyWarningSeverity.alert) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      fgColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else if (sensor.earlyWarningSeverity == EarlyWarningSeverity.advisory) {
      bgColor = Colors.amber.withValues(alpha: 0.15);
      fgColor = Colors.amber.shade800;
      icon = Icons.cloudy_snowing;
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
    final dev = sensor.currentDevice;
    final bool hasSensor = dev?.hasCurrentSensor ?? false;
    final bool isLeak = hasSensor && sensor.isElectricalLeakage;
    Color leakColor = isLeak
        ? Colors.red
        : (!hasSensor ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87));
    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLeak ? Colors.red.withValues(alpha: 0.5) : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isLeak ? Colors.red : (hasSensor ? Colors.green : Colors.grey)).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, color: isLeak ? Colors.red : (hasSensor ? Colors.green : Colors.grey), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('กระแสไฟฟ้า: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(
              child: Text(
                !hasSensor ? 'ไม่ได้ติดตั้งเซนเซอร์' : (isLeak ? 'รั่วไหล (อันตราย!)' : 'ปกติ (ปลอดภัย)'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: leakColor),
                overflow: TextOverflow.ellipsis,
              ),
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
        border: Border.all(color: isLeak ? Colors.red.withValues(alpha: 0.5) : Colors.transparent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasSensor ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt, color: hasSensor ? (isLeak ? Colors.red : Colors.green) : Colors.grey, size: 20),
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            child: Text(!hasSensor ? 'ไม่ได้ติดตั้ง' : (isLeak ? 'รั่วไหล' : 'ปกติ')),
          ),
          const SizedBox(height: 4),
          Text(
            !hasSensor
                ? 'จุดนี้ยังไม่ได้ติดตั้งเซนเซอร์วัดไฟ'
                : (isLeak ? 'ตรวจพบอันตราย' : 'ปลอดภัย ไร้ไฟรั่ว'),
            style: TextStyle(
              fontSize: 12,
              color: isLeak ? Colors.red : Colors.grey,
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
            const Text('สภาพอากาศ: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(
              child: Text(
                isHeavy ? 'ฝนตกหนัก' : (sensor.rainfall > 0 ? 'มีฝนตก' : 'ปกติ'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
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
    final severity = sensor.earlyWarningSeverity;
    final double compoundRate = sensor.compoundRisingSpeed;
    final double rawSpeed = sensor.risingSpeed;
    final bool isCritical = severity == EarlyWarningSeverity.critical;
    final bool isAlert = severity == EarlyWarningSeverity.alert;
    final bool isAdvisory = severity == EarlyWarningSeverity.advisory;
    final bool isHighlighted = isCritical || isAlert;

    Color badgeColor;
    String badgeText;
    Color statusColor;
    String statusDesc;
    IconData statusIcon;

    switch (severity) {
      case EarlyWarningSeverity.critical:
        badgeColor = const Color(0xFFEF4444);
        badgeText = 'วิกฤตเตือนภัยล่วงหน้า';
        statusColor = const Color(0xFFEF4444);
        statusDesc = 'เสี่ยงน้ำท่วมฉับพลันสูง';
        statusIcon = Icons.warning_rounded;
        break;
      case EarlyWarningSeverity.alert:
        badgeColor = const Color(0xFFF97316);
        badgeText = 'เตือนภัยล่วงหน้า';
        statusColor = const Color(0xFFF97316);
        statusDesc = 'น้ำขึ้นเร็ว + เสี่ยงฝน';
        statusIcon = Icons.speed_rounded;
        break;
      case EarlyWarningSeverity.advisory:
        badgeColor = const Color(0xFFEAB308);
        badgeText = 'เฝ้าระวังฝนสะสม';
        statusColor = const Color(0xFFEAB308);
        statusDesc = 'มีปัจจัยฝนตกในพื้นที่';
        statusIcon = Icons.cloudy_snowing;
        break;
      case EarlyWarningSeverity.none:
        badgeColor = const Color(0xFF10B981);
        badgeText = 'สภาวะปกติ';
        if (rawSpeed > 0) {
          statusColor = Colors.blue;
          statusDesc = 'ระดับน้ำค่อยๆ เพิ่ม';
          statusIcon = Icons.trending_up_rounded;
        } else if (rawSpeed < 0) {
          statusColor = Colors.green;
          statusDesc = 'ระดับน้ำกำลังลดลง';
          statusIcon = Icons.trending_down_rounded;
        } else {
          statusColor = Colors.green;
          statusDesc = 'ระดับน้ำทรงตัว ปกติ';
          statusIcon = Icons.trending_flat_rounded;
        }
        break;
    }

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted ? badgeColor.withValues(alpha: 0.5) : (isAdvisory ? badgeColor.withValues(alpha: 0.3) : Colors.transparent),
            width: isHighlighted ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('ความเร็วคาดการณ์: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Flexible(
                        child: Text(
                          '${compoundRate > 0 ? '+' : ''}${compoundRate.toStringAsFixed(1)} ซม./ชม.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'เซนเซอร์ ${rawSpeed > 0 ? '+' : ''}${rawSpeed.toStringAsFixed(1)} • ฝน 30น. ${sensor.forecastRainProb30}%',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(fontSize: 10.5, color: badgeColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isHighlighted
            ? badgeColor.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? badgeColor : (isAdvisory ? badgeColor.withValues(alpha: 0.4) : Colors.transparent),
          width: isHighlighted ? 1.5 : 1.0,
        ),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.speed_rounded, color: badgeColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'วิเคราะห์ความเร็ว & เตือนภัยล่วงหน้า',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'ประมวลผลเซนเซอร์ + พยากรณ์อากาศ AI',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: badgeColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
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
                '${compoundRate > 0 ? '+' : ''}${compoundRate.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? badgeColor : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(width: 6),
              const Text('ซม./ชม.', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
          // Formula breakdown metrics
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.sensors_rounded, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'เซนเซอร์: ${rawSpeed > 0 ? '+' : ''}${rawSpeed.toStringAsFixed(1)} ซม./ชม.',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.umbrella_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'ฝน 30น.: ${sensor.forecastRainProb30}% (${sensor.rainfall.toStringAsFixed(1)} มม.)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (sensor.currentDevice?.earlyWarningColor ?? Colors.blue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (sensor.currentDevice?.earlyWarningColor ?? Colors.blue).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sensor.currentDevice?.earlyWarningIcon ?? Icons.trending_flat_rounded,
                  color: sensor.currentDevice?.earlyWarningColor ?? Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sensor.currentDevice?.compoundTimeToDangerText ?? 'สถานการณ์ปกติ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: sensor.currentDevice?.earlyWarningColor ?? Colors.blue,
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
                    overflow: TextOverflow.ellipsis,
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
    final bool isOnline = device?.isDeviceOnline ?? false;
    final int signalBars = device?.signalBars ?? 0;
    final int signalRssi = device?.signalRssi ?? -100;
    final int signalPercent = device?.signalPercent ?? 0;
    final Color signalColor = device?.signalColor ?? Colors.grey;
    final String qualityText = device?.signalQualityText ?? 'ไม่มีสัญญาณ (ออฟไลน์)';
    final String ssid = device?.wifiSsid ?? '';

    if (sizeMode == WidgetSizeMode.compact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: signalColor.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSignalBarsIndicator(signalBars, signalColor),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: signalColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOnline ? '$signalPercent%' : 'ออฟไลน์',
                    style: TextStyle(color: signalColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isOnline ? '$signalBars/4 ขีด ($signalRssi dBm)' : 'ไม่มีสัญญาณ',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: signalColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isOnline && ssid.isNotEmpty)
              Text(
                'SSID: $ssid',
                style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: signalColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          _buildSignalBarsIndicator(signalBars, signalColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      isOnline ? '$signalBars/4 ขีด ($signalPercent%)' : '0/4 ขีด (ออฟไลน์)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: signalColor,
                      ),
                    ),
                    if (isOnline)
                      Text(
                        '($signalRssi dBm)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                if (isOnline && ssid.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'SSID: $ssid',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            constraints: const BoxConstraints(maxWidth: 135),
            decoration: BoxDecoration(
              color: signalColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              qualityText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: signalColor,
                fontSize: 10.5,
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final bool isActive = index < activeBars;
        final double barHeight = 7.0 + (index * 5.0); // 7px, 12px, 17px, 22px
        return Container(
          width: 5,
          height: barHeight,
          margin: const EdgeInsets.only(right: 2.5),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  void _showDeviceSelectorBottomSheet(BuildContext context, SensorProvider sensor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final devices = sensor.devices.values.toList();
        final selectedId = sensor.selectedDeviceId;
        final theme = Theme.of(context);
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'เลือกสถานีตรวจวัด IoT',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ทั้งหมด ${devices.length} สถานี',
                        style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'แตะสถานีเพื่อสลับการแสดงผลข้อมูลบนแดชบอร์ด',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final dev = devices[index];
                      final bool isSelected = dev.id == selectedId;
                      final bool isOnline = dev.isDeviceOnline;
                      final Color statusColor = isOnline ? Colors.green : Colors.redAccent;

                      return InkWell(
                        onTap: () {
                          sensor.selectDevice(dev.id);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blueAccent.withValues(alpha: 0.12)
                                : theme.cardColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? Colors.blueAccent : Colors.grey.withValues(alpha: 0.2),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isOnline ? Colors.blueAccent : Colors.grey).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sensors_rounded,
                                  color: isOnline ? Colors.blueAccent : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            dev.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isSelected ? Colors.blueAccent : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(isOnline ? Icons.circle : Icons.error_outline_rounded, color: statusColor, size: 6),
                                              const SizedBox(width: 3),
                                              Text(
                                                isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isOnline
                                          ? 'ระดับน้ำ: ${dev.waterLevel.toStringAsFixed(1)} ซม. • Wi-Fi ${dev.signalPercent}%'
                                          : 'ขาดการติดต่อกับอุปกรณ์',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOnline ? Colors.grey : Colors.redAccent.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 22)
                              else
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

