import 'package:flutter/material.dart';

class SafetyGuideScreen extends StatelessWidget {
  final String type; // 'leakage' or 'flood'

  const SafetyGuideScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    bool isLeakage = type == 'leakage';
    const Color bgColor = Color(0xFF111625); // Dark navy background
    const Color cardColor = Color(0xFF1E2433); // Dark navy card

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(isLeakage ? 'ขั้นตอนเมื่อพบไฟฟ้ารั่ว' : 'ขั้นตอนเมื่อเกิดน้ำท่วม'),
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
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.redAccent, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isLeakage ? 'อันตราย! ตรวจพบความเสี่ยงสูง' : 'คำเตือน ระดับน้ำสูงกว่าปกติ',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStep(context, '1', isLeakage ? 'อย่าสัมผัสน้ำ' : 'ขนของขึ้นที่สูง', isLeakage ? 'ห้ามเข้าใกล้หรือสัมผัสน้ำในบริเวณที่แจ้งเตือนว่ามีไฟฟ้ารั่ว' : 'ย้ายสิ่งของมีค่าและเครื่องใช้ไฟฟ้าขึ้นที่สูง', cardColor),
          _buildStep(context, '2', 'ตัดกระแสไฟฟ้าหลัก', 'หากการทำได้ปลอดภัย ให้สับคัทเอาท์ตัดกระแสไฟฟ้า', cardColor),
          _buildStep(context, '3', 'แจ้งเจ้าหน้าที่', 'ติดต่อการไฟฟ้าหรือหน่วยงานกู้ภัยในพื้นที่', cardColor),
          _buildStep(context, '4', 'ช่วยเหลืออย่างถูกวิธี', 'หากมีผู้ประสบเหตุไฟดูด ห้ามใช้มือเปล่าสัมผัสตัวผู้บาดเจ็บ ให้ใช้ไม้ยาวเขี่ยสายไฟออก', cardColor),
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
              label: const Text('โทรขอความช่วยเหลือ (191)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              backgroundColor: Colors.amber, // Yellow circle
              child: Text(number, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
