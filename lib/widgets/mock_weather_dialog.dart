import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/weather_service.dart';
import '../providers/auth_provider.dart';

void showMockWeatherDialog(BuildContext context) {
  final auth = context.read<AuthProvider>();
  if (!auth.isAdmin) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เฉพาะผู้ดูแลระบบ (Admin) เท่านั้นที่สามารถดูและตั้งค่าจำลองได้'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const MockWeatherBottomSheet(),
  );
}

class MockWeatherBottomSheet extends StatefulWidget {
  const MockWeatherBottomSheet({super.key});

  @override
  State<MockWeatherBottomSheet> createState() => _MockWeatherBottomSheetState();
}

class _MockWeatherBottomSheetState extends State<MockWeatherBottomSheet> {
  late bool _isMockActive;
  late double _precipitation;
  late int _prob30;
  late int _prob60;
  late int _prob90;
  late double _temperature;
  late String _description;
  late String _icon;
  String? _selectedPresetKey;

  @override
  void initState() {
    super.initState();
    final sensor = context.read<SensorProvider>();
    _isMockActive = sensor.isMockWeatherEnabled;

    final mock = sensor.mockWeatherData;
    if (mock != null && _isMockActive) {
      _precipitation = ((mock['precipitation'] ?? 25.0) as num).toDouble();
      _prob30 = (mock['prob30'] ?? 75) as int;
      _prob60 = (mock['prob60'] ?? 70) as int;
      _prob90 = (mock['prob90'] ?? 60) as int;
      _temperature = ((mock['temperature'] ?? 26.0) as num).toDouble();
      _description = mock['description']?.toString() ?? 'ฝนตกหนัก';
      _icon = mock['icon']?.toString() ?? '🌧️';
    } else {
      // Default initial mock parameters (Heavy Rain preset for quick demo)
      final preset = WeatherService.presets['heavy_rain']!;
      _precipitation = (preset['precipitation'] as num).toDouble();
      _prob30 = preset['prob30'] as int;
      _prob60 = preset['prob60'] as int;
      _prob90 = preset['prob90'] as int;
      _temperature = (preset['temperature'] as num).toDouble();
      _description = preset['description'] as String;
      _icon = preset['icon'] as String;
      _selectedPresetKey = 'heavy_rain';
    }
  }

  void _applyPreset(String key) {
    final preset = WeatherService.presets[key];
    if (preset == null) return;
    setState(() {
      _selectedPresetKey = key;
      _precipitation = (preset['precipitation'] as num).toDouble();
      _prob30 = preset['prob30'] as int;
      _prob60 = preset['prob60'] as int;
      _prob90 = preset['prob90'] as int;
      _temperature = (preset['temperature'] as num).toDouble();
      _description = preset['description'] as String;
      _icon = preset['icon'] as String;
    });
  }

  void _saveMock() {
    final sensor = context.read<SensorProvider>();
    sensor.setCustomMockWeather(
      temperature: _temperature,
      precipitation: _precipitation,
      description: _description,
      icon: _icon,
      prob30: _prob30,
      prob60: _prob60,
      prob90: _prob90,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'เปิดใช้งานพยากรณ์ฝนจำลอง: $_icon $_description (ฝน $_precipitation mm, โอกาส $_prob30%) สำเร็จ!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetToLive() {
    final sensor = context.read<SensorProvider>();
    sensor.disableMockWeather();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: Colors.lightBlueAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'คืนค่าสภาพอากาศจริงจาก Open-Meteo API เรียบร้อยแล้ว',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1E293B),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'เฉพาะผู้ดูแลระบบ (Admin Only)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'คุณไม่มีสิทธิ์เข้าถึงเครื่องมือจำลองสภาพอากาศนี้',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('🌦️', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'จำลองการพยากรณ์ฝน (Rain Mockup)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ใช้ทดสอบระบบเตือนภัยล่วงหน้า (Early Warning) ในวันที่ฝนไม่ตก',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active State Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isMockActive
                    ? Colors.purple.withValues(alpha: 0.12)
                    : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isMockActive ? Colors.purpleAccent : Colors.greenAccent,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isMockActive ? Icons.science_rounded : Icons.cloud_done_rounded,
                    color: _isMockActive ? Colors.purpleAccent : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isMockActive
                              ? '🔴 โหมดจำลองฝนกำลังทำงาน (Mock Active)'
                              : '🟢 โหมดข้อมูลจริง (Live Open-Meteo API)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _isMockActive ? Colors.purpleAccent : Colors.green,
                          ),
                        ),
                        Text(
                          _isMockActive
                              ? 'ค่าปัจจุบัน: $_icon $_description • ฝน ${_precipitation.toStringAsFixed(1)} mm • โอกาส $_prob30%'
                              : 'ดึงข้อมูลสดตามพิกัดจริงของสถานี/ผู้ใช้',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Preset Title
            const Text(
              'เลือกสถานการณ์จำลองสำเร็จรูป (Quick Presets):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
            const SizedBox(height: 10),

            // 4 Preset Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.85,
              children: [
                _buildPresetCard(
                  keyId: 'sunny',
                  icon: '☀️',
                  title: 'ปลอดฝน (Sunny)',
                  subtitle: 'ฝน 0 mm • โอกาส 5%',
                  tag: 'สภาวะปกติ',
                  color: Colors.blue,
                ),
                _buildPresetCard(
                  keyId: 'cloudy',
                  icon: '⛅',
                  title: 'เมฆมาก / ฝนปรอย',
                  subtitle: 'ฝน 4.5 mm • โอกาส 45%',
                  tag: 'ระดับเฝ้าระวัง',
                  color: Colors.amber.shade700,
                ),
                _buildPresetCard(
                  keyId: 'heavy_rain',
                  icon: '🌧️',
                  title: 'ฝนตกหนัก (Heavy)',
                  subtitle: 'ฝน 25 mm • โอกาส 75%',
                  tag: 'เตือนภัยล่วงหน้า',
                  color: Colors.orange,
                ),
                _buildPresetCard(
                  keyId: 'storm_critical',
                  icon: '⛈️',
                  title: 'พายุวิกฤต (Storm)',
                  subtitle: 'ฝน 55 mm • โอกาส 95%',
                  tag: 'วิกฤตฉุกเฉิน!',
                  color: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Custom Tuning Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        'ปรับแต่งค่าจำลองละเอียด (Custom Sliders):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Slider 1: 30-min Rain Probability
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('โอกาสฝนตกใน 30 นาที:', style: TextStyle(fontSize: 12)),
                      Text(
                        '$_prob30%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _prob30 >= 70 ? Colors.redAccent : (_prob30 >= 40 ? Colors.orange : Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _prob30.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '$_prob30%',
                    activeColor: _prob30 >= 70 ? Colors.redAccent : Colors.blueAccent,
                    onChanged: (val) {
                      setState(() {
                        _selectedPresetKey = null;
                        _prob30 = val.round();
                        _prob60 = (_prob30 * 0.85).round();
                        _prob90 = (_prob30 * 0.70).round();
                        _updateWeatherDescription();
                      });
                    },
                  ),

                  // Slider 2: Rain Precipitation (mm)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ปริมาณน้ำฝนสะสม:', style: TextStyle(fontSize: 12)),
                      Text(
                        '${_precipitation.toStringAsFixed(1)} มม.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                  Slider(
                    value: _precipitation.clamp(0.0, 80.0),
                    min: 0,
                    max: 80,
                    divisions: 16,
                    label: '${_precipitation.toStringAsFixed(1)} mm',
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setState(() {
                        _selectedPresetKey = null;
                        _precipitation = double.parse(val.toStringAsFixed(1));
                        _updateWeatherDescription();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (_isMockActive)
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('คืนค่า API สด', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onPressed: _resetToLive,
                    ),
                  ),
                if (_isMockActive) const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'นำค่าจำลองไปใช้งาน (Apply)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _saveMock,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateWeatherDescription() {
    if (_prob30 >= 80 || _precipitation >= 40) {
      _description = 'พายุฝนฟ้าคะนองรุนแรง วิกฤตน้ำท่วมฉับพลัน';
      _icon = '⛈️';
    } else if (_prob30 >= 60 || _precipitation >= 15) {
      _description = 'ฝนตกหนักในพื้นที่ เสี่ยงน้ำเอ่อท่วม';
      _icon = '🌧️';
    } else if (_prob30 >= 35 || _precipitation > 0) {
      _description = 'มีเมฆมาก โอกาสฝนตกปรอยๆ';
      _icon = '🌦️';
    } else {
      _description = 'ท้องฟ้าแจ่มใส ไม่มีฝน';
      _icon = '☀️';
    }
  }

  Widget _buildPresetCard({
    required String keyId,
    required String icon,
    required String title,
    required String subtitle,
    required String tag,
    required Color color,
  }) {
    final bool isSelected = _selectedPresetKey == keyId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _applyPreset(keyId),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
