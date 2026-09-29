import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/sensor_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final theme = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    
    return Scaffold(
      appBar: isEmbedded ? null : AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ตั้งค่าระบบ', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(sensor.currentDevice?.name ?? 'ไม่มีข้อมูลอุปกรณ์', style: const TextStyle(fontSize: 18)),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent,
                      backgroundImage: auth.photoUrl != null && auth.photoUrl!.isNotEmpty 
                        ? MemoryImage(base64Decode(auth.photoUrl!.split(',').last)) 
                        : null,
                      child: auth.photoUrl == null || auth.photoUrl!.isEmpty
                        ? Text(
                            auth.displayName.isNotEmpty
                                ? auth.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('บัญชีผู้ใช้ (แตะเพื่อแก้ไข)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            auth.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (auth.isAdmin)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Admin', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
            

            const SizedBox(height: 24),
            const Text('การตั้งค่าขั้นสูง (Advanced)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildActionItem(
                    context,
                    title: 'เบอร์ติดต่อฉุกเฉิน (SOS)',
                    subtitle: settings.emergencyNumber,
                    icon: Icons.phone_in_talk,
                    onTap: () => _showEmergencyNumberDialog(context, settings),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text('การแสดงผลและการแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildToggleItem('เสียงแจ้งเตือน', Icons.volume_up, settings.soundEnabled, (v) {
                    context.read<SettingsProvider>().toggleSound(v);
                  }),
                  const Divider(height: 1, color: Colors.black26),
                  _buildToggleItem('การสั่น', Icons.vibration, settings.vibrationEnabled, (v) {
                    context.read<SettingsProvider>().toggleVibration(v);
                  }),
                  const Divider(height: 1, color: Colors.black26),
                  _buildToggleItem('โหมดกลางคืน (Dark Mode)', Icons.dark_mode, theme.isDarkMode, (v) {
                    context.read<ThemeProvider>().toggleTheme();
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (context.watch<AuthProvider>().isAdmin) ...[
              const Text('สำหรับผู้ดูแลระบบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                  title: const Text('จัดการระบบ (Admin Panel)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/admin');
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
                icon: Icon(auth.isGuest ? Icons.login : Icons.logout, color: Colors.white),
                label: Text(auth.isGuest ? 'เข้าสู่ระบบ / สมัครสมาชิก' : 'ออกจากระบบ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: auth.isGuest ? Colors.blue : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: isEmbedded ? null : const AppBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildToggleItem(String title, IconData icon, bool value, void Function(bool)? onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.grey),
      title: Text(title),
      value: value,
      activeColor: Colors.white,
      activeTrackColor: Colors.green,
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.grey[800],
      onChanged: onChanged,
    );
  }

  Widget _buildActionItem(BuildContext context, {required String title, required String subtitle, required IconData icon, Color iconColor = Colors.grey, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.blue)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showEmergencyNumberDialog(BuildContext context, SettingsProvider settings) {
    final TextEditingController controller = TextEditingController(text: settings.emergencyNumber);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ตั้งค่าเบอร์ฉุกเฉิน (SOS)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'หมายเลขโทรศัพท์',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<SettingsProvider>().updateEmergencyNumber(controller.text);
                Navigator.pop(context);
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      }
    );
  }
}
