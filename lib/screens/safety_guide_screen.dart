import 'package:flutter/material.dart';

class SafetyGuideScreen extends StatelessWidget {
  final String type; // 'flood', 'overflow', or 'general'

  const SafetyGuideScreen({super.key, this.type = 'flood'});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF111625); // Dark navy background
    const Color cardColor = Color(0xFF1E2433); // Dark navy card

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('ขั้นตอนปฏิบัติตัวเมื่อเกิดภัยน้ำท่วม'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'คำเตือน: เฝ้าระวังระดับน้ำและเตรียมพร้อมรับมือ',
                    style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStep(context, '1', 'ขนของขึ้นที่สูง', 'ย้ายสิ่งของมีค่า เอกสารสำคัญ และอุปกรณ์ขึ้นชั้นบนหรือที่ปลอดภัย', cardColor),
          _buildStep(context, '2', 'ตัดกระแสไฟฟ้าภายในบ้าน', 'หากน้ำเริ่มเข้าตัวบ้าน ให้สับคัทเอาท์ตัดวงจรไฟฟ้าชั้นล่างเพื่อความปลอดภัย', cardColor),
          _buildStep(context, '3', 'ติดตามระดับน้ำจากสถานีตรวจวัดในพื้นที่', 'ตรวจสอบระดับน้ำและการแจ้งเตือนภัยจากสถานีตรวจวัด IoT ในรัศมีพื้นที่ของคุณผ่านแอปพลิเคชัน', cardColor),
          _buildStep(context, '4', 'เตรียมเส้นทางอพยพ / ขอความช่วยเหลือ', 'หากระดับน้ำวิกฤต กดปุ่ม SOS ในแอพเพื่อส่งพิกัดฉุกเฉินให้เจ้าหน้าที่ทันที', cardColor),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.phone),
              label: const Text('โทรสายด่วนกู้ภัย (1669)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String title, String description, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
