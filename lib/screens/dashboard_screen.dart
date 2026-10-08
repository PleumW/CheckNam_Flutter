import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wave/wave.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_service.dart';
import '../providers/location_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/mock_weather_dialog.dart';
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
    final auth = context.watch<AuthProvider>();
    final bool isAdmin = auth.isAdmin;
    final currentDevice = sensor.currentDevice;

    // ค้นหาอุปกรณ์อื่นในระบบที่อยู่ด้วยกันในรัศมี 20 กม. และกำลังเกิดภาวะวิกฤต
    const double maxNearbyRadiusMeters = 20000.0; // รัศมี 20 กม.
    const distanceCalc = Distance();

    final otherCriticalDevices = sensor.uniqueDeviceList.where((d) {
      if (currentDevice != null && d.id == currentDevice.id) return false;
      // ข้ามกรณีเป็น alias ของเครื่องเดียวกัน (พิกัดเดียวกัน)
      if (currentDevice != null &&
          (d.lat - currentDevice.lat).abs() < 0.0001 &&
          (d.lng - currentDevice.lng).abs() < 0.0001) {
        return false;
      }

      // ตรวจสอบเงื่อนไข: เอาเฉพาะอุปกรณ์ที่อยู่ด้วยกันในรัศมี 20 กม. (เทียบกับสถานีที่กำลังเปิดดูอยู่)
      if (currentDevice != null) {
        final double distM = distanceCalc.as(
          LengthUnit.Meter,
          LatLng(currentDevice.lat, currentDevice.lng),
          LatLng(d.lat, d.lng),
        );
        if (distM > maxNearbyRadiusMeters) {
          return false;
        }
      }

      return d.isDeviceOnline &&
          (d.waterLevel >= 60.0 ||
              d.isFloodDanger ||
              d.earlyWarningSeverity == EarlyWarningSeverity.critical ||
              d.waterLevel >= d.waterLevelThreshold);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        title: GestureDetector(
          onTap: sensor.devices.length > 1 ? () => _showDeviceSelectorBottomSheet(context, sensor) : null,
          onLongPress: isAdmin ? () => Navigator.pushNamed(context, '/simulator') : null,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                            d.isDeviceOnline &&
                            (d.waterLevel >= 60.0 ||
                            d.isFloodDanger ||
                            d.earlyWarningSeverity == EarlyWarningSeverity.critical));

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
              final bool isCritical = sensor.hasProximityFloodAlert ||
                  sensor.devices.values.any((d) =>
                      d.isDeviceOnline &&
                      (d.waterLevel >= 60.0 ||
                      d.isFloodDanger ||
                      d.earlyWarningSeverity == EarlyWarningSeverity.critical));

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
          if (isAdmin)
            GestureDetector(
              onLongPress: () => _showTakeoverTestBottomSheet(context, sensor),
              child: IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () => Navigator.pushNamed(context, '/simulator'),
                tooltip: 'IoT Simulator (Developer) • กดค้างเพื่อทดสอบ Takeover Screen',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!(sensor.currentDevice?.isDeviceOnline ?? false))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'อุปกรณ์กำลัง Offline',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          if (otherCriticalDevices.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.crisis_alert_rounded, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚨 แจ้งเตือน: มีอุปกรณ์ใกล้เคียง (ในรัศมี 20 กม.) เกิดภาวะวิกฤต!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...otherCriticalDevices.map((dev) {
                          String distText = '';
                          final userPos = context.read<LocationProvider>().currentPosition;
                          if (userPos != null) {
                            const distanceCalc = Distance();
                            final meters = distanceCalc.as(
                              LengthUnit.Meter,
                              LatLng(userPos.latitude, userPos.longitude),
                              LatLng(dev.lat, dev.lng),
                            );
                            if (meters >= 1000) {
                              distText = ' • ห่างจากคุณ ${(meters / 1000).toStringAsFixed(1)} กม.';
                            } else if (meters > 10) {
                              distText = ' • ห่างจากคุณ ${meters.toStringAsFixed(0)} ม.';
                            }
                          } else if (currentDevice != null) {
                            const distanceCalc = Distance();
                            final meters = distanceCalc.as(
                              LengthUnit.Meter,
                              LatLng(currentDevice.lat, currentDevice.lng),
                              LatLng(dev.lat, dev.lng),
                            );
                            if (meters >= 1000) {
                              distText = ' • ห่าง ${(meters / 1000).toStringAsFixed(1)} กม.';
                            } else if (meters > 10) {
                              distText = ' • ห่าง ${meters.toStringAsFixed(0)} ม.';
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ตรวจพบระดับน้ำวิกฤตที่ "${dev.name}" (${dev.waterLevel.toStringAsFixed(1)} ซม.)$distText',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    sensor.selectDevice(dev.id);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ดูอุปกรณ์นี้',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.redAccent),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    if (config.id == 'dual_station' || config.id == 'electricity') {
      return const SizedBox.shrink();
    }
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
      case 'dual_station':
      case 'electricity':
        return const SizedBox.shrink();
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
    final sensor = context.watch<SensorProvider>();
    final lat = location.currentPosition?.latitude ?? 13.7563;
    final lng = location.currentPosition?.longitude ?? 100.5018;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${weather['temperature']} °C  •  💧 ${precipVal.toStringAsFixed(1)} มม.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return InkWell(
          onTap: isAdmin ? () => showMockWeatherDialog(context) : null,
          borderRadius: BorderRadius.circular(22),
          child: Container(
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
                                    location.isGpsActive
                                        ? 'พิกัดของคุณ: ${location.placeName ?? "${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}"}'
                                        : 'พิกัด: ${location.coordinatesText}',
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
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
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
                                if (isAdmin && sensor.isMockWeatherEnabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.purpleAccent.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white70, width: 0.8),
                                    ),
                                    child: const Text(
                                      '🧪 MOCK',
                                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${weather['temperature']}°C',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildStatusCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final dev = sensor.currentDevice;
    final bool isOnline = dev?.isDeviceOnline ?? false;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    IconData icon;
    String statusTitle;

    if (!isOnline) {
      bgColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade200;
      fgColor = Colors.grey;
      icon = Icons.cloud_off_rounded;
      statusTitle = 'สถานะ: อุปกรณ์กำลัง Offline';
    } else if (sensor.floodWarningLevel == FloodWarningLevel.emergency) {
      bgColor = const Color(0xFF7F1D1D).withValues(alpha: 0.25);
      fgColor = const Color(0xFFEF4444);
      icon = Icons.emergency_rounded;
      statusTitle = 'สถานะ: ${sensor.systemStatus} (ไซเรนดัง)';
    } else if (sensor.floodWarningLevel == FloodWarningLevel.danger || sensor.earlyWarningSeverity == EarlyWarningSeverity.critical) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      fgColor = Colors.red;
      icon = Icons.warning_rounded;
      statusTitle = 'สถานะ: ${sensor.systemStatus}';
    } else if (sensor.floodWarningLevel == FloodWarningLevel.warning || sensor.earlyWarningSeverity == EarlyWarningSeverity.alert) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      fgColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
      statusTitle = 'สถานะ: ${sensor.systemStatus}';
    } else if (sensor.earlyWarningSeverity == EarlyWarningSeverity.advisory) {
      bgColor = Colors.amber.withValues(alpha: 0.15);
      fgColor = Colors.amber.shade800;
      icon = Icons.cloudy_snowing;
      statusTitle = 'สถานะ: ${sensor.systemStatus}';
    } else {
      bgColor = Colors.green.withValues(alpha: 0.15);
      fgColor = Colors.green;
      icon = Icons.gpp_good;
      statusTitle = 'สถานะ: ${sensor.systemStatus}';
    }

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    return GestureDetector(
      onTap: () {
        if (!isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อุปกรณ์กำลัง Offline — ขาดการติดต่อกับเซนเซอร์ชั่วคราว'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

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

        if (sensor.isFloodDanger) {
          Navigator.pushNamed(context, '/alert_flood');
        } else if (sensor.isFloodWarning || sensor.isEarlyWarning) {
          Navigator.pushNamed(context, '/alert_warning');
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 500),
                    style: Theme.of(context).textTheme.displayMedium!.copyWith(
                      color: fgColor,
                      fontSize: isCompact ? 16 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                    child: Text(statusTitle, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWaterLevelCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final dev = sensor.currentDevice;
    final bool isOnline = dev?.isDeviceOnline ?? false;

    double fillPercent = sensor.waterLevel / 120.0; // Max 120 cm for visual scale
    if (fillPercent > 1.0) fillPercent = 1.0;
    double waveHeight = 1.0 - fillPercent;
    
    Color waveColor;
    Color waveColor2;
    Color statusColor;
    String statusText;

    if (!isOnline) {
      waveColor = Colors.grey.withValues(alpha: 0.05);
      waveColor2 = Colors.grey.withValues(alpha: 0.1);
      waveHeight = 0.98;
      statusColor = Colors.grey;
      statusText = 'อุปกรณ์กำลัง Offline';
    } else if (sensor.floodWarningLevel == FloodWarningLevel.emergency) {
      waveColor = Colors.red.withValues(alpha: 0.4);
      waveColor2 = Colors.red.shade900.withValues(alpha: 0.7);
      statusColor = const Color(0xFFDC2626);
      statusText = 'วิกฤตสูงสุด';
    } else if (sensor.floodWarningLevel == FloodWarningLevel.danger) {
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
                waveAmplitude: isOnline ? 20 : 0,
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
                          child: Icon(
                            isOnline ? Icons.water_drop : Icons.sensors_off_rounded,
                            color: statusColor,
                            size: isCompact ? 20 : 28,
                          ),
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
                              if (!isCompact && isOnline) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'ระยะเซนเซอร์: ${sensor.sensorDistance.toStringAsFixed(0)} ซม. • ${sensor.hardwareStatusText}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
                        isOnline ? '${sensor.waterLevel.toInt()}' : '--',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: isCompact ? 28 : 48,
                          fontWeight: FontWeight.bold,
                          color: isOnline ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ซม.',
                        style: TextStyle(
                          color: isOnline ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey.withValues(alpha: 0.5),
                          fontSize: isCompact ? 13 : 16,
                        ),
                      ),
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


  Widget _buildWeatherStatusCard(BuildContext context, SensorProvider sensor, {WidgetSizeMode sizeMode = WidgetSizeMode.full}) {
    final dev = sensor.currentDevice;
    final bool isOnline = dev?.isDeviceOnline ?? false;
    final bool isHeavy = sensor.isRainingHeavy;
    Color statusColor = !isOnline
        ? Colors.grey
        : (isHeavy ? Colors.orange : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87));
    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (!isOnline) {
      if (isCompact) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 18),
              SizedBox(width: 8),
              Text('สภาพอากาศ: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Expanded(
                child: Text(
                  'อุปกรณ์กำลัง Offline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text('-- มม.', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'สภาพอากาศจากเซนเซอร์',
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
                color: Colors.grey,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              child: const Text('อุปกรณ์กำลัง Offline'),
            ),
            const SizedBox(height: 4),
            const Text(
              'ไม่สามารถอ่านค่าสภาพอากาศจากเซนเซอร์ได้ในขณะนี้',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }

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
    final dev = sensor.currentDevice;
    final bool isOnline = dev?.isDeviceOnline ?? false;
    final severity = sensor.earlyWarningSeverity;
    final int prob30 = isOnline ? sensor.floodRiskProbability30 : 0;
    final int prob60 = isOnline ? sensor.floodRiskProbability60 : 0;
    final bool isCritical = isOnline && (severity == EarlyWarningSeverity.critical || prob30 >= 70 || prob60 >= 70);
    final bool isAlert = isOnline && (severity == EarlyWarningSeverity.alert || prob30 >= 40 || prob60 >= 40);
    final bool isAdvisory = isOnline && (severity == EarlyWarningSeverity.advisory || prob30 >= 20 || prob60 >= 20);
    final bool isHighlighted = isCritical || isAlert;

    Color badgeColor;
    String badgeText;
    Color statusColor;
    String statusDesc;
    IconData statusIcon;

    if (isCritical) {
      badgeColor = const Color(0xFFEF4444);
      badgeText = 'วิกฤต';
      statusColor = const Color(0xFFEF4444);
      statusDesc = 'เสี่ยงน้ำท่วมสูงมาก';
      statusIcon = Icons.warning_rounded;
    } else if (isAlert) {
      badgeColor = const Color(0xFFF97316);
      badgeText = 'เตือนภัย';
      statusColor = const Color(0xFFF97316);
      statusDesc = 'มีความเสี่ยงน้ำท่วม';
      statusIcon = Icons.speed_rounded;
    } else if (isAdvisory) {
      badgeColor = const Color(0xFFEAB308);
      badgeText = 'เฝ้าระวัง';
      statusColor = const Color(0xFFEAB308);
      statusDesc = 'เฝ้าระวังระดับน้ำ';
      statusIcon = Icons.cloudy_snowing;
    } else {
      badgeColor = const Color(0xFF10B981);
      badgeText = 'สภาวะปกติ';
      statusColor = const Color(0xFF10B981);
      statusDesc = 'โอกาสน้ำท่วมต่ำมาก';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    final bool isCompact = sizeMode == WidgetSizeMode.compact;

    if (!isOnline) {
      if (isCompact) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sensors_off_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'โอกาสน้ำท่วม: --%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'อุปกรณ์กำลัง Offline',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Offline',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.bold),
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1.0),
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
                          color: Colors.grey.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sensors_off_rounded, color: Colors.grey, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'พยากรณ์โอกาสน้ำท่วม & ระดับน้ำ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'ประมวลผลเซนเซอร์ + พยากรณ์ฝน AI',
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
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors_off_rounded, color: Colors.grey, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
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
                  child: _buildFloodRiskBox(
                    context: context,
                    timeLabel: 'อีก 30 นาที',
                    timeIcon: Icons.timer_outlined,
                    probability: 0,
                    predictedLevel: 0.0,
                    rainProb: sensor.forecastRainProb30,
                    warningLevel: FloodWarningLevel.safe,
                    isOffline: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFloodRiskBox(
                    context: context,
                    timeLabel: 'อีก 60 นาที',
                    timeIcon: Icons.history_toggle_off_rounded,
                    probability: 0,
                    predictedLevel: 0.0,
                    rainProb: sensor.forecastRainProb60,
                    warningLevel: FloodWarningLevel.safe,
                    isOffline: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'อุปกรณ์ออฟไลน์ ไม่สามารถประเมินโอกาสน้ำท่วมล่วงหน้าได้',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isCompact) {
      final Color riskColor = prob30 >= 70
          ? const Color(0xFFEF4444)
          : (prob30 >= 40 ? const Color(0xFFF97316) : (prob30 >= 20 ? Colors.amber.shade700 : const Color(0xFF10B981)));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Icon(statusIcon, color: riskColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('โอกาสน้ำท่วม: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Flexible(
                        child: Text(
                          '30น: $prob30% • 60น: $prob60%',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: riskColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'คาดการณ์ 30น.: ${sensor.predictedWaterLevel30.toStringAsFixed(1)} ซม. (ฝน ${sensor.forecastRainProb30}%)',
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
      padding: const EdgeInsets.all(16.0),
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
                      child: Icon(Icons.waves_rounded, color: badgeColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'พยากรณ์โอกาสน้ำท่วม & ระดับน้ำ',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const Text(
                            'ประมวลผลเซนเซอร์ + พยากรณ์ฝน AI',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
          // 2 Cards: Flood Risk Probability Forecast (30 min vs 60 min)
          Row(
            children: [
              Expanded(
                child: _buildFloodRiskBox(
                  context: context,
                  timeLabel: 'อีก 30 นาที',
                  timeIcon: Icons.timer_outlined,
                  probability: prob30,
                  predictedLevel: sensor.predictedWaterLevel30,
                  rainProb: sensor.forecastRainProb30,
                  warningLevel: sensor.predictedWarningLevel30,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFloodRiskBox(
                  context: context,
                  timeLabel: 'อีก 60 นาที',
                  timeIcon: Icons.history_toggle_off_rounded,
                  probability: prob60,
                  predictedLevel: sensor.predictedWaterLevel60,
                  rainProb: sensor.forecastRainProb60,
                  warningLevel: sensor.predictedWarningLevel60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Status advisory alert banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (sensor.currentDevice?.earlyWarningColor ?? statusColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (sensor.currentDevice?.earlyWarningColor ?? statusColor).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sensor.currentDevice?.earlyWarningIcon ?? statusIcon,
                  color: sensor.currentDevice?.earlyWarningColor ?? statusColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sensor.currentDevice?.compoundTimeToDangerText ?? statusDesc,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: sensor.currentDevice?.earlyWarningColor ?? statusColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Clean 3-Point Timeline Prediction Chart
          _buildWaterRiseSpeedChart(context, sensor),
        ],
      ),
    );
  }

  Widget _buildFloodRiskBox({
    required BuildContext context,
    required String timeLabel,
    required IconData timeIcon,
    required int probability,
    required double predictedLevel,
    required int rainProb,
    required FloodWarningLevel warningLevel,
    bool isOffline = false,
  }) {
    Color riskColor;
    String riskTitle;
    if (isOffline) {
      riskColor = Colors.grey;
      riskTitle = 'Offline';
    } else if (probability >= 85 || warningLevel == FloodWarningLevel.emergency) {
      riskColor = const Color(0xFFDC2626);
      riskTitle = 'วิกฤตสูงสุด';
    } else if (probability >= 60 || warningLevel == FloodWarningLevel.danger) {
      riskColor = const Color(0xFFEF4444);
      riskTitle = 'เสี่ยงวิกฤต';
    } else if (probability >= 30 || warningLevel == FloodWarningLevel.warning) {
      riskColor = const Color(0xFFF97316);
      riskTitle = 'เฝ้าระวัง';
    } else if (probability >= 15) {
      riskColor = Colors.amber.shade700;
      riskTitle = 'เสี่ยงต่ำ';
    } else {
      riskColor = const Color(0xFF10B981);
      riskTitle = 'ปกติ';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(timeIcon, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  timeLabel,
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  riskTitle,
                  style: TextStyle(fontSize: 8.5, color: riskColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isOffline ? '--%' : '$probability%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'โอกาสท่วม',
                  style: TextStyle(fontSize: 9.5, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isOffline ? 0.0 : (probability / 100.0).clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, size: 11, color: Colors.blueAccent),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  isOffline ? 'คาดการณ์: -- ซม.' : 'คาดการณ์: ${predictedLevel.toStringAsFixed(1)} ซม.',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.cloud_outlined, size: 11, color: Colors.amber),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  'โอกาสฝน: $rainProb%',
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterRiseSpeedChart(BuildContext context, SensorProvider sensor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double currentWater = sensor.waterLevel;
    final double fut30 = sensor.predictedWaterLevel30;
    final double fut60 = sensor.predictedWaterLevel60;
    final double threshold = sensor.waterLevelThreshold > 0 ? sensor.waterLevelThreshold : 60.0;

    // 3 Clean Prediction Spots:
    // X = 0: ตอนนี้ (Current Level)
    // X = 1: อีก 30 นาที (Projected Level)
    // X = 2: อีก 60 นาที (Projected Level)
    final List<FlSpot> spots = [
      FlSpot(0, currentWater.clamp(0.0, 300.0)),
      FlSpot(1, fut30.clamp(0.0, 300.0)),
      FlSpot(2, fut60.clamp(0.0, 300.0)),
    ];

    final double highestVal = [
      currentWater,
      fut30,
      fut60,
      threshold,
    ].reduce((a, b) => a > b ? a : b);

    final double chartMaxY = (((highestVal * 1.3) / 10).ceil() * 10.0).clamp(60.0, 350.0);

    final Color lineColor = (fut30 >= threshold || fut60 >= threshold)
        ? const Color(0xFFEF4444)
        : (sensor.predictedWarningLevel30 == FloodWarningLevel.warning || fut30 >= 20
            ? const Color(0xFFF97316)
            : const Color(0xFF0284C7));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'กราฟแนวโน้มระดับน้ำคาดการณ์ (1 ชม. ข้างหน้า):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMaxY,
                minX: 0,
                maxX: 2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: (chartMaxY / 3).clamp(15.0, 80.0),
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}ซม.',
                        style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        final int idx = val.toInt();
                        String label = '';
                        Color color = Colors.grey.shade500;
                        FontWeight weight = FontWeight.normal;
                        switch (idx) {
                          case 0:
                            label = 'ตอนนี้';
                            color = const Color(0xFF0284C7);
                            weight = FontWeight.bold;
                            break;
                          case 1:
                            label = '+30 นาที';
                            color = const Color(0xFFF97316);
                            weight = FontWeight.bold;
                            break;
                          case 2:
                            label = '+60 นาที';
                            color = lineColor;
                            weight = FontWeight.bold;
                            break;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 9.5, color: color, fontWeight: weight),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: threshold,
                      color: const Color(0xFFEF4444).withValues(alpha: 0.75),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 6, bottom: 2),
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (line) => 'เกณฑ์วิกฤต (${threshold.toInt()} ซม.)',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final int x = spot.x.toInt();
                        String time = '';
                        int floodProb = 0;
                        switch (x) {
                          case 0:
                            time = 'ปัจจุบัน';
                            floodProb = (currentWater >= threshold) ? 100 : ((currentWater / threshold) * 50).round();
                            break;
                          case 1:
                            time = 'อีก 30 นาที';
                            floodProb = sensor.floodRiskProbability30;
                            break;
                          case 2:
                            time = 'อีก 60 นาที';
                            floodProb = sensor.floodRiskProbability60;
                            break;
                        }
                        return LineTooltipItem(
                          '$time: ${spot.y.toStringAsFixed(1)} ซม.\nโอกาสน้ำท่วม: $floodProb%',
                          TextStyle(
                            color: spot.bar.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    barWidth: 3.2,
                    color: lineColor,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          lineColor.withValues(alpha: 0.28),
                          lineColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: lineColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend using Wrap to ensure ZERO overflow on ANY screen
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendItem(lineColor, 'ระดับน้ำคาดการณ์ (เซนเซอร์ + ฝน AI)'),
              _buildLegendItem(const Color(0xFFEF4444), 'เกณฑ์วิกฤต (${threshold.toInt()} ซม.)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
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

      if (device.isFloodDanger || device.isFloodWarning) {
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

    final bool isTargetOnline = targetDevice.isDeviceOnline;
    final bool isFloodDanger = isTargetOnline && targetDevice.isFloodDanger;
    final bool isRisk = isTargetOnline && nearestRiskDevice != null;

    final Color accentColor = !isTargetOnline
        ? Colors.grey
        : (isFloodDanger ? const Color(0xFFEF4444) : (isRisk ? const Color(0xFFF59E0B) : const Color(0xFF10B981)));

    final IconData statusIcon = !isTargetOnline
        ? Icons.sensors_off_rounded
        : (isFloodDanger ? Icons.warning_amber_rounded : (isRisk ? Icons.error_outline_rounded : Icons.shield_rounded));

    final String statusTitle = !isTargetOnline
        ? 'สถานี ${targetDevice.name} กำลัง Offline'
        : (isFloodDanger ? 'รัศมีเสี่ยงน้ำท่วมวิกฤต' : (isRisk ? 'อยู่ในรัศมีเฝ้าระวัง' : 'พิกัดของคุณอยู่ในเขตปลอดภัย'));

    final String statusSubtitle = !isTargetOnline
        ? 'ห่างจากคุณ $distText • ขาดการเชื่อมต่อ ไม่สามารถประเมินภัยพิบัติได้'
        : (isRisk
            ? 'สถานี ${targetDevice.name} • ห่างจากคุณเพียง $distText'
            : 'สถานีที่ใกล้ที่สุด: ${targetDevice.name} ($distText) • สภาวะปกติ');

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
    final dev = sensor.currentDevice;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    final double lat = dev?.lat ?? 13.7563;
    final double lng = dev?.lng ?? 100.5018;

    final String stationName = dev?.name ?? 'สถานีตรวจวัด IoT';
    final String coordText = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

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

        // Sync IoT sensor rain readings with weather forecast (Only in real sensor mode, never override in Mock mode)
        if (!sensor.isMockWeatherEnabled) {
          if (sensor.rainfall >= 40 || sensor.isRainingHeavy) {
            prob30 = prob30 < 95 ? 95 : prob30;
            prob60 = prob60 < 85 ? 85 : prob60;
            prob90 = prob90 < 70 ? 70 : prob90;
          } else if (sensor.rainfall > 5.0) {
            prob30 = prob30 < 75 ? 75 : prob30;
            prob60 = prob60 < 60 ? 60 : prob60;
            prob90 = prob90 < 45 ? 45 : prob90;
          }
        }

        final Color cardAccent = prob30 >= 60 ? Colors.orange : Colors.blue;

        final String locPrefix = 'บริเวณสถานี $stationName';
        String forecastSummary;
        if (sensor.rainfall >= 40 || sensor.isRainingHeavy) {
          forecastSummary = '$locPrefix ขณะนี้ฝนตกหนัก คาดว่าฝนจะตกต่อเนื่องอีก 30-60 นาที ($prob30%)';
        } else if (sensor.rainfall > 0) {
          forecastSummary = '$locPrefix ขณะนี้มีฝนตกในพื้นที่ คาดว่าจะมีฝนตกต่อเนื่อง ($prob30%)';
        } else if (prob30 >= 70) {
          forecastSummary = '$locPrefix มีโอกาสเกิดฝนตกหนักในอีก 30 นาทีข้างหน้า ($prob30%)';
        } else if (prob30 >= 40) {
          forecastSummary = '$locPrefix คาดว่าอาจมีฝนตกปรอยๆ ใน 30-60 นาทีข้างหน้า ($prob30%)';
        } else {
          forecastSummary = '$locPrefix ท้องฟ้าโปร่ง โอกาสเกิดฝนตกต่ำ ($prob30%)';
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'พยากรณ์ฝนล่วงหน้า (สถานี IoT)',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'พิกัดสถานี: $stationName ($coordText)',
                                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    InkWell(
                      onTap: () => showMockWeatherDialog(context),
                      borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sensor.isMockWeatherEnabled
                            ? Colors.purple.withValues(alpha: 0.18)
                            : cardAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: sensor.isMockWeatherEnabled
                            ? Border.all(color: Colors.purpleAccent, width: 1.2)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sensor.isMockWeatherEnabled ? Icons.science_rounded : Icons.tune_rounded,
                            size: 11,
                            color: sensor.isMockWeatherEnabled ? Colors.purpleAccent : cardAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sensor.isMockWeatherEnabled ? 'จำลอง 🧪' : 'จำลองฝน',
                            style: TextStyle(
                              color: sensor.isMockWeatherEnabled ? Colors.purpleAccent : cardAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
              isOnline ? '$signalBars/4 ขีด ($signalRssi dBm)' : 'ไม่มีสัญญาณ (ออฟไลน์)',
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

  void _showTakeoverTestBottomSheet(BuildContext context, SensorProvider sensor) {
    if (!context.read<AuthProvider>().isAdmin) return;
    final currentDev = sensor.currentDevice ??
        (sensor.devices.isNotEmpty ? sensor.devices.values.first : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ทดสอบ Takeover Screen (Debug Menu)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            Text(
                              'เลือกสถานะเพื่อเปิดดูหน้าจอเตือนภัย Takeover Screen ทันที',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDC2626),
                      child: Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('🚨 วิกฤตสูงสุด (Emergency: ≥ 50 ซม.)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('ระดับน้ำ 65 ซม. (เซนเซอร์ 35 ซม.) • ไฟแดงติด ไซเรนดังกระหึ่ม! • รถดับ 100% ห้ามผ่านเด็ดขาด', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    onTap: () {
                      Navigator.pop(ctx);
                      final devId = currentDev?.id ?? 'device_1';
                      final lat = currentDev?.lat ?? 13.7563;
                      final lng = currentDev?.lng ?? 100.5018;

                      // อัปเดตข้อมูลระดับน้ำใน SensorProvider ทันทีเพื่อให้ตัวอุปกรณ์เปลี่ยนสถานะตามจริง
                      sensor.simulateDataFromIoT(
                        deviceId: devId,
                        lat: lat,
                        lng: lng,
                        waterLevel: 65.0,
                        waterFlow: 30.0,
                        rainfall: 45.0,
                        isOnline: true,
                      );
                      sensor.selectDevice(devId);

                      final testDev = sensor.devices[devId] ?? DeviceData(
                        id: devId,
                        name: currentDev?.name ?? 'สถานีตรวจวัด IoT',
                        lat: lat,
                        lng: lng,
                        waterLevel: 65.0,
                        waterLevelThreshold: 30.0,
                        isOnline: true,
                      );
                      AudioAlarmService().startSiren();
                      Navigator.pushNamed(context, '/proximity_alert', arguments: testDev);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEF4444),
                      child: Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('🔴 สภาวะวิกฤต (Critical: 30 - 49.9 ซม.)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('ระดับน้ำ 40 ซม. (เซนเซอร์ 60 ซม.) • ไฟแดงติด Buzzer เงียบ • รถเล็กและมอเตอร์ไซค์ห้ามผ่านเด็ดขาด', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    onTap: () {
                      Navigator.pop(ctx);
                      final devId = currentDev?.id ?? 'device_1';
                      final lat = currentDev?.lat ?? 13.7563;
                      final lng = currentDev?.lng ?? 100.5018;

                      sensor.simulateDataFromIoT(
                        deviceId: devId,
                        lat: lat,
                        lng: lng,
                        waterLevel: 40.0,
                        waterFlow: 15.0,
                        rainfall: 20.0,
                        isOnline: true,
                      );
                      sensor.selectDevice(devId);

                      final testDev = sensor.devices[devId] ?? DeviceData(
                        id: devId,
                        name: currentDev?.name ?? 'สถานีตรวจวัด IoT',
                        lat: lat,
                        lng: lng,
                        waterLevel: 40.0,
                        waterLevelThreshold: 30.0,
                        isOnline: true,
                      );
                      Navigator.pushNamed(context, '/proximity_alert', arguments: testDev);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF97316),
                      child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('🟠 สถานะเฝ้าระวัง (Warning: 10 - 29.9 ซม.)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('ระดับน้ำ 20 ซม. (เซนเซอร์ 80 ซม.) • ไฟเหลืองติด Buzzer เงียบ • รถเก๋งเริ่มสัญจรลำบาก', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    onTap: () {
                      Navigator.pop(ctx);
                      final devId = currentDev?.id ?? 'device_1';
                      final lat = currentDev?.lat ?? 13.7563;
                      final lng = currentDev?.lng ?? 100.5018;

                      sensor.simulateDataFromIoT(
                        deviceId: devId,
                        lat: lat,
                        lng: lng,
                        waterLevel: 20.0,
                        waterFlow: 8.0,
                        rainfall: 5.0,
                        isOnline: true,
                      );
                      sensor.selectDevice(devId);

                      final testDev = sensor.devices[devId] ?? DeviceData(
                        id: devId,
                        name: currentDev?.name ?? 'สถานีตรวจวัด IoT',
                        lat: lat,
                        lng: lng,
                        waterLevel: 20.0,
                        waterLevelThreshold: 30.0,
                        isOnline: true,
                      );
                      Navigator.pushNamed(context, '/proximity_alert', arguments: testDev);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF22C55E),
                      child: Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('🟢 สภาวะปกติ (Normal: 0 - 9.9 ซม.)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('ระดับน้ำ 5 ซม. (เซนเซอร์ 95 ซม.) • ไฟเขียวติด Buzzer เงียบ • ถนนแห้ง รถผ่านสะดวก', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    onTap: () {
                      Navigator.pop(ctx);
                      final devId = currentDev?.id ?? 'device_1';
                      final lat = currentDev?.lat ?? 13.7563;
                      final lng = currentDev?.lng ?? 100.5018;

                      sensor.simulateDataFromIoT(
                        deviceId: devId,
                        lat: lat,
                        lng: lng,
                        waterLevel: 5.0,
                        waterFlow: 5.0,
                        rainfall: 0.0,
                        isOnline: true,
                      );
                      sensor.selectDevice(devId);

                      final testDev = sensor.devices[devId] ?? DeviceData(
                        id: devId,
                        name: currentDev?.name ?? 'สถานีตรวจวัด IoT',
                        lat: lat,
                        lng: lng,
                        waterLevel: 5.0,
                        waterLevelThreshold: 30.0,
                        isOnline: true,
                      );
                      Navigator.pushNamed(context, '/proximity_alert', arguments: testDev);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF9333EA),
                      child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('⚡ เตือนภัยล่วงหน้าน้ำพุ่งเร็ว (Early Warning)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('อัตราน้ำพุ่งเร็ว +14 ซม./ชม. เสี่ยงน้ำท่วมล่วงหน้า', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.05),
                    onTap: () {
                      Navigator.pop(ctx);
                      final devId = currentDev?.id ?? 'device_1';
                      final lat = currentDev?.lat ?? 13.7563;
                      final lng = currentDev?.lng ?? 100.5018;

                      // อัปเดตข้อมูลระดับน้ำใน SensorProvider ทันทีเพื่อให้ตัวอุปกรณ์เปลี่ยนสถานะตามจริง
                      sensor.simulateDataFromIoT(
                        deviceId: devId,
                        lat: lat,
                        lng: lng,
                        waterLevel: 32.0,
                        waterFlow: 20.0,
                        rainfall: 30.0,
                        isOnline: true,
                      );
                      sensor.selectDevice(devId);

                      final testDev = sensor.devices[devId] ?? DeviceData(
                        id: devId,
                        name: currentDev?.name ?? 'สถานีตรวจวัด IoT',
                        lat: lat,
                        lng: lng,
                        waterLevel: 32.0,
                        risingSpeed: 14.0,
                        isRainingHeavy: true,
                        rainfall: 30.0,
                        forecastRainProb30: 80,
                        waterLevelThreshold: 30.0,
                        isOnline: true,
                      );
                      Navigator.pushNamed(context, '/proximity_alert', arguments: testDev);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF2563EB),
                      child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('🔊 ทดสอบเสียงไซเรนฉุกเฉิน (3 วินาที)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('ทดสอบการเล่นเสียง siren.wav และตรวจลำโพงมือถือโดยตรง', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.blueAccent.withValues(alpha: 0.12),
                    onTap: () {
                      AudioAlarmService().playTestSiren(duration: const Duration(seconds: 3));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.volume_up_rounded, color: Colors.lightBlueAccent, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('กำลังเล่นเสียงไซเรนทดสอบ 3 วินาที (หากไม่ได้ยิน ให้เปิดเสียง Media หรือปิดโหมดเงียบบนมือถือ)'),
                              ),
                            ],
                          ),
                          backgroundColor: Color(0xFF1E293B),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('เปิดหน้าจำลอง IoT Simulator เต็มรูปแบบ'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/simulator');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

