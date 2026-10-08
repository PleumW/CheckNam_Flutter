import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/location_provider.dart';
import '../providers/sensor_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/sos_emergency_modal.dart';

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
  late Stream<DatabaseEvent> _sosStream;
  late AnimationController _pulseController;

  bool _isSatellite = false;
  bool _showTraffic = false;

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
    _sosStream = _dbRef.child('sos_requests').onValue;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    final sensor = context.watch<SensorProvider>();
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
          Consumer<SensorProvider>(
            builder: (context, sensor, child) {
              final uniqueList = sensor.uniqueDeviceList;
              if (uniqueList.isEmpty) return const SizedBox.shrink();

              final validIds = uniqueList.map((d) => d.id).toSet();
              final selectedValue = validIds.contains(sensor.selectedDeviceId)
                  ? sensor.selectedDeviceId
                  : (validIds.contains(sensor.currentDevice?.id)
                      ? sensor.currentDevice!.id
                      : uniqueList.first.id);

              final primaryColor = Theme.of(context).colorScheme.primary;

              return Container(
                margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedValue,
                    isDense: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    borderRadius: BorderRadius.circular(14),
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
                    items: uniqueList.map((device) {
                      final isSelected = device.id == selectedValue;
                      return DropdownMenuItem<String>(
                        value: device.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: device.statusColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 135),
                              child: Text(
                                device.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
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
                  return StreamBuilder<DatabaseEvent>(
                    stream: _sosStream,
                    builder: (context, sosSnapshot) {
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
                      for (final device in sensor.devices.values) {
                        final double lat = device.lat;
                        final double lng = device.lng;
                        final double waterLevel = device.waterLevel;
                        final double rainfall = device.rainfall;
                        final bool isOffline = !device.isDeviceOnline;
                        Color pinColor = isOffline
                            ? Colors.grey
                            : (device.isFloodDanger
                                ? Colors.red
                                : (device.isFloodWarning ? Colors.orange : (device.isUpstream ? const Color(0xFF0284C7) : const Color(0xFF8B5CF6))));

                        // 1. Flood Risk Buffer Zones (Circle Layer)
                        if (!isOffline) {
                          if (device.isFloodDanger) {
                            // High Flood Danger Buffer Zone (1000m radius)
                            circles.add(CircleMarker(
                              point: LatLng(lat, lng),
                              color: Colors.red.withValues(alpha: 0.20),
                              borderColor: Colors.red,
                              borderStrokeWidth: 2,
                              radius: 1000,
                              useRadiusInMeter: true,
                            ));
                          } else if (device.isFloodWarning || waterLevel >= 20 || rainfall >= 30) {
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

                        // Station Markers (Riverbank 🌊 / Urban 🏙️)
                        markers.add(
                          Marker(
                            point: LatLng(lat, lng),
                            width: 145,
                            height: 75,
                            child: GestureDetector(
                              onTap: () {
                                _showDeviceInfo(context, device.id, device.name, waterLevel, isOffline, lat, lng);
                              },
                              child: _buildDeviceMarkerWidget(device, pinColor, waterLevel),
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

                      // Build Persistent SOS Emergency Requests Map
                      // หมุดพิกัด SOS จะคงอยู่บนแผนที่เสมอจนกว่าจะได้รับความช่วยเหลือ (status == 'resolved')
                      final Map<String, SosRequest> activeSosMap = {};

                      // 1. Initial / Cached data from SensorProvider
                      for (final sos in sensor.sosRequests) {
                        if (sos.status != 'resolved') {
                          activeSosMap[sos.id] = sos;
                        }
                      }

                      // 2. Real-time Firebase stream updates
                      if (sosSnapshot.hasData && sosSnapshot.data?.snapshot.value != null) {
                        final raw = sosSnapshot.data!.snapshot.value;
                        if (raw is Map) {
                          raw.forEach((key, val) {
                            if (val is Map) {
                              try {
                                final req = SosRequest.fromJson(key.toString(), val);
                                if (req.status != 'resolved') {
                                  activeSosMap[req.id] = req;
                                } else {
                                  activeSosMap.remove(req.id);
                                }
                              } catch (_) {}
                            }
                          });
                        } else if (raw is List) {
                          for (int i = 0; i < raw.length; i++) {
                            final val = raw[i];
                            if (val is Map) {
                              try {
                                final req = SosRequest.fromJson(i.toString(), val);
                                if (req.status != 'resolved') {
                                  activeSosMap[req.id] = req;
                                } else {
                                  activeSosMap.remove(req.id);
                                }
                              } catch (_) {}
                            }
                          }
                        }
                      }

                      // Add SOS Markers & Emergency Buffer Circles
                      for (final sos in activeSosMap.values) {
                        final bool isInProgress = sos.status == 'in_progress';
                        final Color sosColor = isInProgress ? Colors.orange : Colors.redAccent;
                        final String badgeText = isInProgress ? 'กำลังช่วย' : 'SOS ด่วน';

                        // วงรัศมีฉุกเฉินรอบพิกัด SOS เพื่อให้สังเกตเห็นได้ชัดเจนบนแผนที่
                        circles.add(
                          CircleMarker(
                            point: LatLng(sos.lat, sos.lng),
                            color: sosColor.withValues(alpha: 0.16),
                            borderColor: sosColor,
                            borderStrokeWidth: 1.8,
                            radius: 80,
                            useRadiusInMeter: true,
                          ),
                        );

                        markers.add(
                          Marker(
                            point: LatLng(sos.lat, sos.lng),
                            width: 72,
                            height: 64,
                            child: GestureDetector(
                              onTap: () => _showSosInfo(context, sos),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sosColor,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(color: sosColor.withValues(alpha: 0.5), blurRadius: 4),
                                      ],
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Icon(Icons.location_on_rounded, color: sosColor, size: 30),
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
                              CircleLayer(circles: circles),
                              MarkerLayer(markers: markers),
                            ],
                          ),
                          
                          // Floating Distance Range & Risk Banner
                          if (locationProvider.currentPosition != null && sensor.devices.isNotEmpty)
                            Positioned(
                              top: 12,
                              left: 16,
                              right: 16,
                              child: _buildDistanceRiskBanner(context, locationProvider, sensor),
                            ),

                          // SOS Emergency Button in Bottom-Left corner
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                key: const ValueKey('map_sos_btn'),
                                onPressed: () => SosEmergencyModal.show(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  elevation: 5,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    side: const BorderSide(color: Colors.white, width: 1.5),
                                  ),
                                  shadowColor: Colors.redAccent.withValues(alpha: 0.5),
                                ),
                                child: const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
            heroTag: 'device_location_fab',
            tooltip: 'เลื่อนไปยังอุปกรณ์ IoT จริง (ESP32)',
            onPressed: () {
              final activeDev = sensor.currentDevice ??
                  sensor.devices['device_1'] ??
                  (sensor.devices.isNotEmpty ? sensor.devices.values.first : null);
              if (activeDev != null) {
                _mapController.move(LatLng(activeDev.lat, activeDev.lng), 16.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          activeDev.isGpsLocked ? Icons.satellite_alt_rounded : Icons.sensors_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '📍 ตำแหน่ง ${activeDev.name} (${activeDev.lat.toStringAsFixed(4)}, ${activeDev.lng.toStringAsFixed(4)}) ${activeDev.isGpsLocked ? "[🛰️ GPS จริง]" : ""}',
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            backgroundColor: const Color(0xFF0284C7),
            mini: true,
            child: const Icon(Icons.sensors_rounded, color: Colors.white),
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

  Widget _buildDeviceMarkerWidget(DeviceData device, Color pinColor, double waterLevel) {
    final bool isDanger = device.isFloodDanger;
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
              color: isDanger
                  ? const Color(0xFFEF4444)
                  : (isWarning ? const Color(0xFFF59E0B) : device.stationTypeColor),
              width: isDanger ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDanger
                    ? pinColor.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.25),
                blurRadius: isDanger ? 10 : 6,
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
                        Icon(
                          device.stationTypeIcon,
                          color: device.stationTypeColor,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            device.name,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.isGpsLocked) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.satellite_alt_rounded,
                            color: Color(0xFF10B981),
                            size: 10,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      device.isDeviceOnline ? '${waterLevel.toStringAsFixed(1)} ซม.' : 'ออฟไลน์ (อ่านค่าไม่ได้)',
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

      if (device.isDeviceOnline && (device.isFloodDanger || device.isFloodWarning)) {
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

    final bool isOffline = !targetDevice.isDeviceOnline;
    final isDanger = targetDevice.isFloodDanger && !isOffline;

    final Color accentColor = isOffline
        ? Colors.grey
        : (isDanger
            ? const Color(0xFFEF4444)
            : (isRisk ? const Color(0xFFF59E0B) : const Color(0xFF10B981)));

    final IconData statusIcon = isOffline
        ? Icons.sensors_off_rounded
        : (isDanger
            ? Icons.warning_amber_rounded
            : (isRisk ? Icons.error_outline_rounded : Icons.verified_user_rounded));

    final String statusTitle = isOffline
        ? 'อุปกรณ์ออฟไลน์ (ขาดการติดต่อ)'
        : (isDanger
            ? 'เตือนภัยระดับน้ำวิกฤต'
            : (isRisk ? 'เฝ้าระวังระดับน้ำ' : 'ปลอดภัย • สภาวะปกติ'));

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
                                  boxShadow: (isRisk && !isOffline) ? [
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
                        isOffline
                            ? '${targetDevice.name} • ออฟไลน์ (ไม่ได้รับข้อมูลสด) • ห่าง $distText'
                            : '${targetDevice.name} • ห่าง $distText',
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

  void _showDeviceInfo(BuildContext context, String deviceId, String name, double waterLevel, bool isOffline, double devLat, double devLng) {
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
                              ? Colors.redAccent.withValues(alpha: 0.15) 
                              : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOffline ? Colors.redAccent.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOffline ? Colors.redAccent : Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOffline ? 'ออฟไลน์ (ขาดการติดต่อ)' : 'ออนไลน์',
                              style: TextStyle(
                                color: isOffline ? Colors.redAccent : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // GIS Coordinates & Real Hardware GPS Telemetry
                  Builder(
                    builder: (context) {
                      final dev = context.read<SensorProvider>().devices[deviceId];
                      final bool isGpsLocked = dev?.isGpsLocked ?? false;
                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isGpsLocked
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : Colors.blueGrey.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isGpsLocked
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : Colors.blueGrey.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isGpsLocked ? Icons.satellite_alt_rounded : Icons.location_on_rounded,
                                color: isGpsLocked ? const Color(0xFF10B981) : Colors.blueGrey,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'พิกัด GIS ตำแหน่งอุปกรณ์:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isGpsLocked
                                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                              : Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isGpsLocked ? '🛰️ ล็อกดาวเทียมจริง' : '📍 พิกัดสถานี',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isGpsLocked ? const Color(0xFF10B981) : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${devLat.toStringAsFixed(6)}, ${devLng.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sensors_off_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'อุปกรณ์นี้ออฟไลน์อยู่ ไม่สามารถอ่านค่าระดับน้ำได้จนกว่าอุปกรณ์จะกลับมาออนไลน์',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          title: 'ระดับน้ำ',
                          value: isOffline ? 'ออฟไลน์ (อ่านค่าไม่ได้)' : '${waterLevel.toStringAsFixed(1)} ซม.',
                          icon: isOffline ? Icons.sensors_off_rounded : Icons.water_drop_rounded,
                          color: isOffline ? Colors.grey : (waterLevel >= 60 ? Colors.red : (waterLevel >= 20 ? Colors.orange : Colors.blue)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final dev = context.read<SensorProvider>().devices[deviceId];
                            final stationName = dev?.stationTypeName ?? 'สถานีตรวจวัด';
                            return _buildInfoCard(
                              context,
                              title: 'จุดตรวจวัด',
                              value: isOffline ? '$stationName (ออฟไลน์)' : stationName,
                              icon: isOffline ? Icons.sensors_off_rounded : (dev?.stationTypeIcon ?? Icons.location_city_rounded),
                              color: isOffline ? Colors.grey : (dev?.stationTypeColor ?? const Color(0xFF0284C7)),
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
                  if (!isOffline)
                    Builder(
                      builder: (context) {
                        final dev = context.read<SensorProvider>().devices[deviceId];
                        if (dev == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: dev.earlyWarningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: dev.earlyWarningColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(dev.earlyWarningIcon, color: dev.earlyWarningColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'พยากรณ์ระดับน้ำล่วงหน้า (คำนวณผ่าน App):',
                                      style: TextStyle(
                                        color: dev.earlyWarningColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'อีก 30 นาที: ${dev.predictedWaterLevel30.toStringAsFixed(1)} ซม. | อีก 60 นาที: ${dev.predictedWaterLevel60.toStringAsFixed(1)} ซม. (โอกาสฝน ${dev.forecastRainProb30}%)',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // One-Touch Geolocation Sync Button (ซิงค์พิกัดอุปกรณ์ตาม GPS มือถือปัจจุบัน)
                  if (userPos != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                          backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.08),
                        ),
                        icon: const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF0284C7)),
                        label: const Text(
                          'ซิงค์พิกัดอุปกรณ์ตาม GPS มือถือฉัน',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                        onPressed: () async {
                          await context.read<SensorProvider>().updateDeviceLocation(
                            deviceId,
                            userPos.latitude,
                            userPos.longitude,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            _mapController.move(LatLng(userPos.latitude, userPos.longitude), 16.0);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ ซิงค์พิกัดอุปกรณ์ "$name" ไปยังตำแหน่งจริงเรียบร้อยแล้ว (${userPos.latitude.toStringAsFixed(4)}, ${userPos.longitude.toStringAsFixed(4)})',
                                ),
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
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
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold),
            maxLines: 2,
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

  Future<void> _confirmResolveSos(BuildContext context, SosRequest sos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ยืนยันได้รับความช่วยเหลือ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'ยืนยันว่าผู้ประสบภัย "${sos.userName}" ได้รับความช่วยเหลือเรียบร้อยแล้วใช่หรือไม่?\n\nเมื่อยืนยันแล้ว หมุดพิกัด SOS จะถูกนำออกจากแผนที่ทันที',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน (ช่วยเหลือแล้ว)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final sensor = context.read<SensorProvider>();
      await sensor.updateSosStatus(sos.id, 'resolved');
      if (context.mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'บันทึกว่า "${sos.userName}" ได้รับการช่วยเหลือแล้ว และนำหมุดออกจากแผนที่เรียบร้อย',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  void _showSosInfo(BuildContext context, SosRequest sos) {
    final locationProvider = context.read<LocationProvider>();
    final LatLng? userPos = locationProvider.currentPosition != null
        ? LatLng(locationProvider.currentPosition!.latitude, locationProvider.currentPosition!.longitude)
        : null;
    final distanceText = _calculateDistanceText(userPos, LatLng(sos.lat, sos.lng));

    final bool isPending = sos.status == 'pending';
    final bool isInProgress = sos.status == 'in_progress';
    final Color statusColor = isPending ? Colors.redAccent : (isInProgress ? Colors.orange : Colors.green);
    final String statusLabel = isPending ? 'รอดำเนินการช่วยเหลือ' : (isInProgress ? 'กำลังเข้าช่วยเหลือ' : 'ช่วยเหลือแล้ว');
    final String timeStr = '${sos.timestamp.hour.toString().padLeft(2, '0')}:${sos.timestamp.minute.toString().padLeft(2, '0')} น.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.sos_rounded, color: statusColor, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ขอความช่วยเหลือฉุกเฉิน (SOS)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                            Text(
                              'เวลา: $timeStr • ห่างจากคุณ: $distanceText',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Persistent Pin Notice & Status Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(isPending ? Icons.warning_amber_rounded : Icons.directions_run_rounded, color: statusColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'สถานะ: $statusLabel • หมุดพิกัดจะแสดงอยู่จนกว่าจะได้รับความช่วยเหลือ',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Victim details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ผู้ประสบภัย: ${sos.userName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (sos.nickname.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text('ชื่อเล่น: ${sos.nickname}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                        if (sos.englishName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text('ชื่อสากล (EN): ${sos.englishName}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                        if (sos.dob.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text('วันเกิด (ค.ศ.): ${sos.dob}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                        const SizedBox(height: 6),
                        Text('เหตุฉุกเฉิน: ${sos.situation}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                        if (sos.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('รายละเอียด: ${sos.note}', style: const TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Colors.blueAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'พิกัด GPS: ${sos.lat.toStringAsFixed(6)}, ${sos.lng.toStringAsFixed(6)} ($distanceText)',
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons: Row 1 (Navigation + Call)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('นำทาง GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          onPressed: () => _openGoogleMapsNavigation(sos.lat, sos.lng),
                        ),
                      ),
                      if (sos.phoneNumber.isNotEmpty && sos.phoneNumber != '-') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.phone, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('โทร: ${sos.phoneNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            onPressed: () async {
                              final uri = Uri.parse('tel:${sos.phoneNumber}');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action Button: In-progress update (if pending)
                  if (isPending) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.directions_run_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('🟠 กำลังเดินทางเข้าช่วยเหลือ (เปลี่ยนสถานะ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        onPressed: () async {
                          final sensor = context.read<SensorProvider>();
                          await sensor.updateSosStatus(sos.id, 'in_progress');
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('อัปเดตสถานะเป็น "กำลังเข้าช่วยเหลือ" เรียบร้อยแล้ว (หมุดยังคงอยู่บนแผนที่)'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Action Button: Resolve assistance (Remove pin from map)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '✅ ยืนยันได้รับความช่วยเหลือแล้ว (นำหมุดออกจากแผนที่)',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: () => _confirmResolveSos(context, sos),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ปิดหน้าต่าง', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

