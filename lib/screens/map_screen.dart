import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/location_provider.dart';
import '../providers/sensor_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_nav_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  late Stream<DatabaseEvent> _devicesStream;
  late Stream<DatabaseEvent> _reportsStream;
  late Stream<DatabaseEvent> _postsStream;
  late AnimationController _pulseController;

  bool _isSatellite = false;
  bool _showRadar = false;
  bool _showTraffic = false;
  String? _radarPath;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _devicesStream = _dbRef.child('devices').onValue;
    _reportsStream = _dbRef.child('admin_reports').onValue;
    _postsStream = _dbRef.child('community_posts').onValue;
    _fetchRadarData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchRadarData() async {
    try {
      final response = await http.get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final past = data['radar']['past'] as List;
        if (past.isNotEmpty) {
          setState(() {
            _radarPath = past.last['path'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching radar data: $e');
    }
  }

  String _calculateDistanceText(LatLng? userPos, LatLng targetPos) {
    if (userPos == null) return 'ไม่ทราบพิกัดของคุณ';
    const Distance distance = Distance();
    final double meters = distance.as(LengthUnit.Meter, userPos, targetPos);
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} กม.';
    }
    return '${meters.toInt()} ม.';
  }

  double _calculateDistanceMeters(LatLng? userPos, LatLng targetPos) {
    if (userPos == null) return double.infinity;
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, userPos, targetPos);
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final LatLng center = locationProvider.currentPosition != null 
      ? LatLng(locationProvider.currentPosition!.latitude, locationProvider.currentPosition!.longitude)
      : const LatLng(13.7563, 100.5018); // Default to Bangkok

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CheckNam',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'เช็คน้ำ เฝ้าระวังภัย',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          Container(
            width: 78, // Extra mini width for dropdown
            height: 28,
            margin: const EdgeInsets.only(right: 12, top: 13, bottom: 13),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
            ),
            child: Consumer<SensorProvider>(
              builder: (context, sensor, child) {
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: sensor.selectedDeviceId,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue, size: 14),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        sensor.selectDevice(newValue);
                        final device = sensor.devices[newValue];
                        if (device != null) {
                          _mapController.move(
                            LatLng(device.lat, device.lng),
                            16.0,
                          );
                        }
                      }
                    },
                    items: sensor.devices.values.map((device) {
                      return DropdownMenuItem<String>(
                        value: device.id,
                        child: Text(
                          device.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _devicesStream,
        builder: (context, deviceSnapshot) {
          return StreamBuilder<DatabaseEvent>(
            stream: _reportsStream,
            builder: (context, reportSnapshot) {
              return StreamBuilder<DatabaseEvent>(
                stream: _postsStream,
                builder: (context, postsSnapshot) {
                  final Set<String> activePostKeys = {};
                  if (postsSnapshot.hasData && postsSnapshot.data?.snapshot.value != null) {
                    final postsVal = postsSnapshot.data!.snapshot.value;
                    if (postsVal is Map) {
                      postsVal.forEach((key, value) {
                        if (key != null) {
                          activePostKeys.add(key.toString());
                        }
                      });
                    }
                  }
              
              List<Marker> markers = [];
              List<CircleMarker> circles = [];
              
              // Add User Location Marker
              if (locationProvider.currentPosition != null) {
                markers.add(
                  Marker(
                    point: LatLng(locationProvider.currentPosition!.latitude, locationProvider.currentPosition!.longitude),
                    width: 110,
                    height: 70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue, width: 1),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                          ),
                          child: const Text(
                            'พิกัดของคุณ',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
                      ],
                    ),
                  ),
                );
              }

              // Add Device Markers & Risk Buffer Circles
              final sensor = context.watch<SensorProvider>();
              for (final device in sensor.devices.values) {
                final double lat = device.lat;
                final double lng = device.lng;
                final isLeakage = device.isElectricalLeakage;
                final double waterLevel = device.waterLevel;
                final double rainfall = device.rainfall;
                final bool isOffline = !device.isDeviceOnline;
                Color pinColor = isOffline
                    ? Colors.grey
                    : (isLeakage || waterLevel >= 60
                        ? Colors.red
                        : (waterLevel >= 20 || rainfall >= 30 ? Colors.orange : Colors.green));

                // 1. Flood Risk & Electrical Hazard Buffer Zones (Circle Layer)
                if (!isOffline) {
                  if (isLeakage) {
                    // Electrical Danger Buffer Zone (300m radius with amber alert border)
                    circles.add(CircleMarker(
                      point: LatLng(lat, lng),
                      color: Colors.red.withValues(alpha: 0.30),
                      borderColor: Colors.amber,
                      borderStrokeWidth: 3,
                      radius: 300,
                      useRadiusInMeter: true,
                    ));
                  }
                  
                  if (waterLevel >= 60) {
                    // High Flood Danger Buffer Zone (1000m radius)
                    circles.add(CircleMarker(
                      point: LatLng(lat, lng),
                      color: Colors.red.withValues(alpha: 0.20),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                      radius: 1000,
                      useRadiusInMeter: true,
                    ));
                  } else if (waterLevel >= 20 || rainfall >= 30) {
                    // Flood Warning Buffer Zone (500m radius)
                    circles.add(CircleMarker(
                      point: LatLng(lat, lng),
                      color: Colors.orange.withValues(alpha: 0.20),
                      borderColor: Colors.orange,
                      borderStrokeWidth: 2,
                      radius: 500,
                      useRadiusInMeter: true,
                    ));
                  }
                }

                // 4. Pulsing Electrical Hazard Marker & standard markers
                markers.add(
                  Marker(
                    point: LatLng(lat, lng),
                    width: 145,
                    height: 75,
                    child: GestureDetector(
                      onTap: () {
                        _showDeviceInfo(context, device.id, device.name, waterLevel, isLeakage, isOffline, lat, lng);
                      },
                      child: _buildDeviceMarkerWidget(device, pinColor, isLeakage, waterLevel),
                    ),
                  ),
                );
              }

              // Add Report Markers
              if (reportSnapshot.hasData && reportSnapshot.data?.snapshot.value != null) {
                final reportData = reportSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                int reportOffset = 1;
                final now = DateTime.now().millisecondsSinceEpoch;
                final oneDayMs = 24 * 60 * 60 * 1000;

                reportData.forEach((key, value) {
                  if (value is! Map) return;

                  final timestamp = value['timestamp'] ?? 0;
                  if (now - timestamp > oneDayMs) {
                    return;
                  }

                  // ตรวจสอบว่าหากเป็นรายงานที่ผูกกับโพสต์ชุมชน และโพสต์นั้นถูกลบไปแล้ว ให้ตัดสัญลักษณ์เตือนภัยออกจากแผนที่ทันที
                  final String? postId = value['postId']?.toString();
                  if (postId != null && postId.isNotEmpty && !activePostKeys.contains(postId)) {
                    return;
                  }

                  final lat = value['lat'] ?? (center.latitude - (reportOffset * 0.005));
                  final lng = value['lng'] ?? (center.longitude - (reportOffset * 0.005));
                  
                  markers.add(
                    Marker(
                      point: LatLng(lat, lng),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          _showReportInfo(context, value['reason'] ?? 'ไม่มีเหตุผล', value['reportedBy'] ?? 'Unknown');
                        },
                        child: const Icon(Icons.report_problem, color: Colors.orange, size: 36),
                      ),
                    ),
                  );
                  reportOffset++;
                });
              }

              // Add SOS Emergency Markers
              for (final sos in sensor.sosRequests) {
                if (sos.status == 'resolved') continue;
                markers.add(
                  Marker(
                    point: LatLng(sos.lat, sos.lng),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _showSosInfo(context, sos),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 4),
                              ],
                            ),
                            child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 28),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _isSatellite
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flutter_application_water_flood',
                      ),
                      if (_showTraffic)
                        TileLayer(
                          urlTemplate: 'https://mt1.google.com/vt/lyrs=h,traffic&z={z}&x={x}&y={y}',
                          userAgentPackageName: 'com.example.flutter_application_water_flood',
                        ),
                      if (_showRadar && _radarPath != null)
                        TileLayer(
                          urlTemplate: 'https://tilecache.rainviewer.com$_radarPath/256/{z}/{x}/{y}/2/1_1.png',
                          userAgentPackageName: 'com.example.flutter_application_water_flood',
                          maxNativeZoom: 6,
                          maxZoom: 18,
                        ),
                      CircleLayer(circles: circles),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  
                  // 5. Floating Distance Range & Risk Banner
                  if (locationProvider.currentPosition != null && sensor.devices.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: _buildDistanceRiskBanner(context, locationProvider, sensor),
                    ),
                ],
              );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'traffic_fab',
            onPressed: () {
              setState(() {
                _showTraffic = !_showTraffic;
              });
            },
            backgroundColor: _showTraffic ? Colors.redAccent : Colors.white,
            mini: true,
            child: Icon(Icons.traffic, color: _showTraffic ? Colors.white : Colors.blue),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'radar_fab',
            onPressed: () {
              setState(() {
                _showRadar = !_showRadar;
              });
            },
            backgroundColor: _showRadar ? Colors.orange : Colors.white,
            mini: true,
            child: Icon(Icons.cloudy_snowing, color: _showRadar ? Colors.white : Colors.blue),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'satellite_fab',
            onPressed: () {
              setState(() {
                _isSatellite = !_isSatellite;
              });
            },
            backgroundColor: _isSatellite ? Colors.green : Colors.white,
            mini: true,
            child: Icon(Icons.satellite_alt, color: _isSatellite ? Colors.white : Colors.blue),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'my_location_fab',
            onPressed: () {
              if (locationProvider.currentPosition != null) {
                _mapController.move(center, 15.0);
              }
            },
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildDeviceMarkerWidget(DeviceData device, Color pinColor, bool isLeakage, double waterLevel) {
    final bool isDanger = device.isFloodDanger || isLeakage;
    final bool isWarning = device.isFloodWarning && !isDanger;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 145),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xEE1E293B), // Dark slate glass container
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLeakage 
                  ? Colors.amber 
                  : (isDanger ? const Color(0xFFEF4444) : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6))),
              width: isLeakage || isDanger ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isLeakage || isDanger) 
                    ? pinColor.withValues(alpha: 0.5) 
                    : Colors.black.withValues(alpha: 0.25),
                blurRadius: isLeakage || isDanger ? 10 : 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: pinColor.withValues(alpha: 0.8), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLeakage) ...[
                          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            device.name,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      device.isDeviceOnline ? '${waterLevel.toStringAsFixed(1)} ซม.' : 'ออฟไลน์',
                      style: TextStyle(
                        fontSize: 9.5, 
                        color: Colors.white.withValues(alpha: 0.85), 
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_drop_down, color: pinColor, size: 20),
      ],
    );

    return content;
  }

  Widget _buildDistanceRiskBanner(BuildContext context, LocationProvider locationProvider, SensorProvider sensor) {
    final userPos = locationProvider.currentPosition;
    if (userPos == null) return const SizedBox.shrink();

    final userLatLng = LatLng(userPos.latitude, userPos.longitude);
    const double maxAlertRadiusMeters = 100000.0; // 100 กม.

    DeviceData? nearestRiskDevice;
    double minRiskDist = double.infinity;

    DeviceData? nearestDevice;
    double minDeviceDist = double.infinity;

    for (final device in sensor.devices.values) {
      final dist = _calculateDistanceMeters(userLatLng, LatLng(device.lat, device.lng));
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
    final isRisk = nearestRiskDevice != null;

    if (targetDevice == null) return const SizedBox.shrink();

    final double targetDistMeters = _calculateDistanceMeters(userLatLng, LatLng(targetDevice.lat, targetDevice.lng));
    
    // Only display alert banner if user is within 100 km radius
    if (targetDistMeters > maxAlertRadiusMeters) {
      return const SizedBox.shrink();
    }

    final distText = _calculateDistanceText(userLatLng, LatLng(targetDevice.lat, targetDevice.lng));

    final isElectrical = targetDevice.isElectricalLeakage;
    final isDanger = targetDevice.isFloodDanger || isElectrical;

    final Color accentColor = isElectrical
        ? Colors.amber
        : (isDanger ? const Color(0xFFEF4444) : (isRisk ? const Color(0xFFF59E0B) : const Color(0xFF10B981)));

    final IconData statusIcon = isElectrical
        ? Icons.bolt_rounded
        : (isDanger ? Icons.warning_amber_rounded : (isRisk ? Icons.error_outline_rounded : Icons.verified_user_rounded));

    final String statusTitle = isElectrical
        ? 'เสี่ยงไฟฟ้ารั่ว'
        : (isDanger ? 'เตือนภัยระดับน้ำวิกฤต' : (isRisk ? 'เฝ้าระวังระดับน้ำ' : 'ปลอดภัย • สภาวะปกติ'));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xEE0F172A) : Colors.white.withValues(alpha: 0.92);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _mapController.move(LatLng(targetDevice.lat, targetDevice.lng), 16.0);
            _showDeviceInfo(
              context,
              targetDevice.id,
              targetDevice.name,
              targetDevice.waterLevel,
              targetDevice.isElectricalLeakage,
              !targetDevice.isDeviceOnline,
              targetDevice.lat,
              targetDevice.lng,
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Minimal glowing status badge
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(statusIcon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: isRisk ? [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.6 * _pulseController.value),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    )
                                  ] : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusTitle,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${targetDevice.name} • ห่าง $distText',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'รายละเอียด',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, color: accentColor, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeviceInfo(BuildContext context, String deviceId, String name, double waterLevel, bool isLeakage, bool isOffline, double devLat, double devLng) {
    final locationProvider = context.read<LocationProvider>();
    final userPos = locationProvider.currentPosition;
    final LatLng? userLatLng = userPos != null ? LatLng(userPos.latitude, userPos.longitude) : null;
    final String distText = userLatLng != null ? _calculateDistanceText(userLatLng, LatLng(devLat, devLng)) : 'ไม่ทราบพิกัดของคุณ';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              )
            ],
          ),
          padding: const EdgeInsets.all(24.0),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimal Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'สถานีตรวจวัด ID: $deviceId',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOffline 
                              ? Colors.grey.withValues(alpha: 0.15) 
                              : (isLeakage ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOffline ? Colors.grey : (isLeakage ? Colors.red : Colors.green),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOffline ? 'ออฟไลน์' : (isLeakage ? 'รั่วไหล!' : 'ออนไลน์'),
                              style: TextStyle(
                                color: isOffline ? Colors.grey : (isLeakage ? Colors.red : Colors.green),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          title: 'ระดับน้ำ',
                          value: '${waterLevel.toStringAsFixed(1)} ซม.',
                          icon: Icons.water_drop_rounded,
                          color: waterLevel >= 60 ? Colors.red : (waterLevel >= 20 ? Colors.orange : Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final hasCurrent = context.read<SensorProvider>().devices[deviceId]?.hasCurrentSensor ?? false;
                            return _buildInfoCard(
                              context,
                              title: 'ระบบไฟฟ้า',
                              value: !hasCurrent ? 'ไม่ได้ติดตั้ง' : (isLeakage ? 'ไฟฟ้ารั่ว!' : 'ปกติ'),
                              icon: Icons.bolt_rounded,
                              color: !hasCurrent ? Colors.grey : (isLeakage ? Colors.amber : Colors.green),
                            );
                          }
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          title: 'ระยะห่าง',
                          value: distText,
                          icon: Icons.near_me_rounded,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ปิด', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.analytics_rounded, size: 18),
                          label: const Text('ดูแดชบอร์ด', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            context.read<SensorProvider>().selectDevice(deviceId);
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(context, '/dashboard');
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showReportInfo(BuildContext context, String reason, String reporter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รายงานแจ้งเหตุ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 16),
                Text('ผู้แจ้ง: $reporter'),
                Text('รายละเอียด: $reason'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ปิด'),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
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

  void _showSosInfo(BuildContext context, SosRequest sos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sos_rounded, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('ขอความช่วยเหลือฉุกเฉิน (SOS)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('ผู้ประสบภัย: ${sos.userName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('เหตุฉุกเฉิน: ${sos.situation}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                if (sos.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('รายละเอียด: ${sos.note}', style: const TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 4),
                Text('พิกัด: ${sos.lat.toStringAsFixed(6)}, ${sos.lng.toStringAsFixed(6)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ปิด'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('นำทาง', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _openGoogleMapsNavigation(sos.lat, sos.lng),
                      ),
                    ),
                    if (sos.phoneNumber.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('โทร', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final uri = Uri.parse('tel:${sos.phoneNumber}');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

