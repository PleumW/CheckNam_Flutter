import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class CommunityPost {
  final String key;
  final String author;
  final String location;
  final String description;
  final int timestamp;
  final Map<String, bool> likedBy;
  final Map<String, bool> dislikedBy;
  final bool isDanger;
  final String deviceId;
  final String? imageUrl;
  final bool isReported;
  final Uint8List? imageBytes;

  CommunityPost({
    required this.key,
    required this.author,
    required this.location,
    required this.description,
    required this.timestamp,
    required this.likedBy,
    required this.dislikedBy,
    required this.isDanger,
    required this.deviceId,
    required this.isReported,
    this.imageUrl,
    this.imageBytes,
  });

  factory CommunityPost.fromSnapshot(DataSnapshot snapshot) {
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
    final String? imgUrl = data['imageUrl'];
    Uint8List? bytes;
    if (imgUrl != null && imgUrl.startsWith('data:image')) {
      try {
        final base64Str = imgUrl.contains(',') ? imgUrl.split(',').last : imgUrl;
        bytes = base64Decode(base64Str);
      } catch (_) {}
    }
    return CommunityPost(
      key: snapshot.key ?? '',
      author: data['author'] ?? 'ไม่ทราบชื่อ',
      location: data['location'] ?? 'ไม่ระบุ',
      description: data['description'] ?? '',
      timestamp: data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      likedBy: (data['likedBy'] as Map<dynamic, dynamic>? ?? {}).map((k, v) => MapEntry(k.toString(), v == true)),
      dislikedBy: (data['dislikedBy'] as Map<dynamic, dynamic>? ?? {}).map((k, v) => MapEntry(k.toString(), v == true)),
      isDanger: data['isDanger'] ?? false,
      deviceId: data['deviceId'] ?? '',
      isReported: data['isReported'] ?? false,
      imageUrl: imgUrl,
      imageBytes: bytes,
    );
  }

  String get exactTime {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year + 543} เวลา ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.';
  }

  int get likesCount => likedBy.length;
  int get dislikesCount => dislikedBy.length;
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('community_posts');
  final DatabaseReference _adminReportsRef = FirebaseDatabase.instance.ref().child('admin_reports');
  final Map<String, Uint8List> _imageCache = {};

  DateTime? _selectedDate;

  String _generateShareText(CommunityPost post) {
    final header = post.isDanger ? '🚨 [แจ้งเตือนเหตุวิกฤต/น้ำท่วม]' : '📢 [รายงานสถานการณ์น้ำท่วม GIS]';
    return '''$header
📍 สถานที่: ${post.location}
📝 รายละเอียด: ${post.description}
⏰ เวลาแจ้ง: ${post.exactTime}
👤 ผู้รายงาน: ${post.author}
🌊 ผ่านระบบเฝ้าระวังน้ำท่วมและเตือนภัยอัจฉริยะ (GIS Water Flood Alert)''';
  }

  void _showShareBottomSheet(CommunityPost post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shareText = _generateShareText(post);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'แชร์รายงานเหตุการณ์',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ส่งต่อข้อมูลเตือนภัยไปยังเครือข่ายสังคมออนไลน์',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: post.isDanger ? Colors.redAccent.withValues(alpha: 0.4) : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          post.isDanger ? Icons.warning_rounded : Icons.location_on_rounded,
                          color: post.isDanger ? Colors.redAccent : Colors.blueAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.location,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: post.isDanger ? Colors.redAccent : Colors.blueAccent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.isDanger)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ระวังภัย', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.description,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'เลือกช่องทางที่ต้องการแชร์:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSocialShareButton(
                    label: 'Facebook',
                    iconWidget: const Icon(Icons.facebook, color: Colors.white, size: 28),
                    color: const Color(0xFF1877F2),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _shareToFacebook(shareText);
                    },
                  ),
                  _buildSocialShareButton(
                    label: 'LINE',
                    iconWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LINE',
                        style: TextStyle(
                          color: Color(0xFF06C755),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    color: const Color(0xFF06C755),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _shareToLine(shareText);
                    },
                  ),
                  _buildSocialShareButton(
                    label: 'Twitter (X)',
                    iconWidget: const Text(
                      '𝕏',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    color: Colors.black,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _shareToTwitter(shareText);
                    },
                  ),
                  _buildSocialShareButton(
                    label: 'แชร์อื่นๆ',
                    iconWidget: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                    color: const Color(0xFF2563EB),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _shareGeneric(shareText, post.isDanger);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('คัดลอกข้อความรายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('คัดลอกข้อความรายงานเรียบร้อยแล้ว'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSocialShareButton({
    required String label,
    required Widget iconWidget,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(child: iconWidget),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToFacebook(String text) async {
    // ก๊อปปี้ข้อความเตรียมไว้ในคลิปบอร์ดแบบเงียบๆ เผื่อผู้ใช้ต้องการกดวางในช่องโพสต์
    await Clipboard.setData(ClipboardData(text: text));

    // Deep link schemes สำหรับเปิดแอป Facebook โดยตรงบน Android และ iOS
    final Uri fbAppUri = Uri.parse('fb://facewebmodal/f?href=https://www.facebook.com');
    final Uri fbFeedUri = Uri.parse('fb://feed');
    final Uri fbWebUri = Uri.parse('https://www.facebook.com/sharer/sharer.php?quote=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(fbAppUri)) {
        await launchUrl(fbAppUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
      if (await canLaunchUrl(fbFeedUri)) {
        await launchUrl(fbFeedUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
      final launched = await launchUrl(fbWebUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(ShareParams(text: text, subject: 'รายงานเหตุการณ์น้ำท่วม'));
      }
    } catch (_) {
      try {
        await launchUrl(fbWebUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await SharePlus.instance.share(ShareParams(text: text, subject: 'รายงานเหตุการณ์น้ำท่วม'));
      }
    }
  }

  Future<void> _shareToLine(String text) async {
    final Uri lineAppUri = Uri.parse('line://msg/text/${Uri.encodeComponent(text)}');
    final Uri lineWebUri = Uri.parse('https://line.me/R/msg/text/?${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(lineAppUri)) {
        await launchUrl(lineAppUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
      final launched = await launchUrl(lineWebUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(ShareParams(text: text, subject: 'รายงานเหตุการณ์น้ำท่วม'));
      }
    } catch (_) {
      try {
        await launchUrl(lineWebUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await SharePlus.instance.share(ShareParams(text: text, subject: 'รายงานเหตุการณ์น้ำท่วม'));
      }
    }
  }

  Future<void> _shareToTwitter(String text) async {
    final Uri twitterAppUri = Uri.parse('twitter://post?message=${Uri.encodeComponent(text)}');
    final Uri twitterWebUri = Uri.parse('https://x.com/intent/tweet?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(twitterAppUri)) {
        await launchUrl(twitterAppUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
      final launched = await launchUrl(twitterWebUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(ShareParams(text: text, subject: 'รายงานเหตุการณ์น้ำท่วม'));
      }
    } catch (_) {
      try {
        await launchUrl(twitterWebUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await SharePlus.instance.share(ShareParams(text: text, subject: 'รายงานเหตุการณ์น้ำท่วม'));
      }
    }
  }

  Future<void> _shareGeneric(String text, bool isDanger) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: isDanger ? 'แจ้งเตือนเหตุวิกฤตน้ำท่วม' : 'รายงานสถานการณ์น้ำท่วม',
        ),
      );
    } catch (e) {
      debugPrint('Share generic error: $e');
    }
  }

  Future<void> _deletePostAndAssociatedReports(String postKey) async {
    try {
      // 1. ลบโพสต์ออกจาก community_posts
      await _dbRef.child(postKey).remove();

      // 2. ค้นหาและลบรายการแจ้งเหตุใน admin_reports ที่ผูกกับโพสต์นี้ออกด้วย เพื่อเอาสัญลักษณ์เตือนภัยในแผนที่ออก
      try {
        final reportsSnapshot = await _adminReportsRef.orderByChild('postId').equalTo(postKey).get();
        if (reportsSnapshot.exists && reportsSnapshot.value is Map) {
          final reportsMap = reportsSnapshot.value as Map<dynamic, dynamic>;
          for (final rKey in reportsMap.keys) {
            await _adminReportsRef.child(rKey.toString()).remove();
          }
        }
      } catch (_) {}

      // Fallback: ตรวจสอบและลบแบบสแกนทุกรายการเพื่อความปลอดภัยสูงสุด
      final allReportsSnap = await _adminReportsRef.get();
      if (allReportsSnap.exists && allReportsSnap.value is Map) {
        final allReportsMap = allReportsSnap.value as Map<dynamic, dynamic>;
        for (final entry in allReportsMap.entries) {
          if (entry.value is Map && entry.value['postId']?.toString() == postKey) {
            await _adminReportsRef.child(entry.key.toString()).remove();
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting post and associated reports: $e');
      await _dbRef.child(postKey).remove();
    }
  }

  void _showDeleteConfirmDialog(String postKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ลบโพสต์'),
          content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบโพสต์นี้? การลบไม่สามารถเรียกคืนได้ และสัญลักษณ์เตือนภัยในแผนที่จะถูกนำออกด้วย'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _deletePostAndAssociatedReports(postKey);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบโพสต์และนำสัญลักษณ์เตือนภัยออกจากแผนที่เรียบร้อยแล้ว')));
                }
              },
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  void _showReportPostDialog(CommunityPost post, String currentUserName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('รายงานโพสต์'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'เหตุผลที่รายงาน', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาระบุเหตุผลที่รายงาน')));
                  return;
                }
                
                final locationProvider = context.read<LocationProvider>();
                final pos = locationProvider.currentPosition;
                
                await _adminReportsRef.push().set({
                  'reason': reasonController.text,
                  'reportedBy': currentUserName,
                  'postAuthor': post.author,
                  'postContent': post.description,
                  'postId': post.key,
                  'deviceId': post.deviceId,
                  'timestamp': ServerValue.timestamp,
                  if (pos != null) 'lat': pos.latitude,
                  if (pos != null) 'lng': pos.longitude,
                });
                
                // Set isReported flag on the post itself
                await _dbRef.child('community_posts/${post.key}').update({
                  'isReported': true
                });
                
                if (context.mounted) {
                    Navigator.pop(context); // close report dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('สำเร็จ', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                        content: const Text('ส่งรายงานให้ผู้ดูแลระบบแล้ว'),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // close success dialog
                            },
                            child: const Text('ตกลง'),
                          )
                        ],
                      ),
                    );
                  }
              },
              child: const Text('ส่งรายงาน'),
            ),
          ],
        );
      }
    );
  }

  void _showReportDialog(String currentDeviceId) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.isGuest || auth.role == 'guest') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('จำกัดสิทธิ์การใช้งาน'),
          content: const Text('ผู้เยี่ยมชมไม่สามารถแจ้งเหตุได้ กรุณาเข้าสู่ระบบเพื่อใช้งานฟังก์ชันนี้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ไว้คราวหลัง', style: TextStyle(color: Colors.grey)),
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

    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isDanger = false;
    File? selectedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('แจ้งเหตุการณ์ในพื้นที่'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'สถานที่', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'รายละเอียดเหตุการณ์', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    if (selectedImage != null) ...[
                      Image.file(selectedImage!, height: 120, fit: BoxFit.cover),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 600);
                            if (picked != null) {
                              setState(() => selectedImage = File(picked.path));
                            }
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('ถ่ายรูป'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 600);
                            if (picked != null) {
                              setState(() => selectedImage = File(picked.path));
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('คลังภาพ'),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('เป็นอันตรายรุนแรง?'),
                      value: isDanger,
                      activeColor: Colors.red,
                      onChanged: (v) => setState(() => isDanger = v),
                    ),
                    if (isUploading) const LinearProgressIndicator(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context), 
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (locationController.text.trim().isEmpty || descriptionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกสถานที่และรายละเอียดเหตุการณ์ให้ครบถ้วน')));
                      return;
                    }
                    
                    setState(() => isUploading = true);
                    final auth = context.read<AuthProvider>();
                    final email = auth.user?.email ?? 'ผู้ใช้งานทั่วไป';
                    final shortName = email.split('@').first;
                      
                      String? imageUrl;
                      if (selectedImage != null) {
                        try {
                          final bytes = await selectedImage!.readAsBytes();
                          imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                        } catch (e) {
                          debugPrint('Upload/Encode failed: $e');
                        }
                      }

                      // Push to Firebase
                      final newPostRef = _dbRef.push();
                      await newPostRef.set({
                        'author': shortName,
                        'location': locationController.text,
                        'description': descriptionController.text,
                        'timestamp': ServerValue.timestamp,
                        'isDanger': isDanger,
                        'deviceId': currentDeviceId,
                        'imageUrl': imageUrl,
                      });
                      
                      final locationProvider = context.read<LocationProvider>();
                      final pos = locationProvider.currentPosition;
                      
                      // Send report to admin
                      await _adminReportsRef.push().set({
                        'reason': 'รายงานแจ้งเหตุการณ์ใหม่จากผู้ใช้',
                        'reportedBy': shortName,
                        'postAuthor': shortName,
                        'postContent': 'สถานที่: ${locationController.text}\nรายละเอียด: ${descriptionController.text}',
                        'postId': newPostRef.key,
                        'deviceId': currentDeviceId,
                        'timestamp': ServerValue.timestamp,
                        if (pos != null) 'lat': pos.latitude,
                        if (pos != null) 'lng': pos.longitude,
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context); // close post dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('สำเร็จ', style: TextStyle(color: Colors.green)),
                              ],
                            ),
                            content: const Text('โพสต์และส่งรายงานไปยังผู้ดูแลระบบเรียบร้อยแล้ว'),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('ตกลง'),
                              )
                            ],
                          ),
                        );
                      }
                  },
                  child: const Text('โพสต์รายงาน'),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _toggleLike(String postKey, String currentUserId, Map<String, bool> likedBy, Map<String, bool> dislikedBy) {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบเพื่อกดถูกใจโพสต์')),
      );
      return;
    }
    
    final postRef = _dbRef.child(postKey);
    if (likedBy.containsKey(currentUserId)) {
      // Unlike
      postRef.child('likedBy').child(currentUserId).remove();
    } else {
      // Like
      postRef.child('likedBy').child(currentUserId).set(true);
      // Remove dislike if exists
      if (dislikedBy.containsKey(currentUserId)) {
        postRef.child('dislikedBy').child(currentUserId).remove();
      }
    }
  }

  void _toggleDislike(String postKey, String currentUserId, Map<String, bool> likedBy, Map<String, bool> dislikedBy) {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบเพื่อกดไม่ถูกใจโพสต์')),
      );
      return;
    }
    
    final postRef = _dbRef.child(postKey);
    if (dislikedBy.containsKey(currentUserId)) {
      // Undislike
      postRef.child('dislikedBy').child(currentUserId).remove();
    } else {
      // Dislike
      postRef.child('dislikedBy').child(currentUserId).set(true);
      // Remove like if exists
      if (likedBy.containsKey(currentUserId)) {
        postRef.child('likedBy').child(currentUserId).remove();
      }
    }
  }

  String? _lastDeviceId;
  Stream<DatabaseEvent>? _postsStream;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.uid ?? '';
    final currentUserName = auth.user?.email?.split('@').first ?? 'ผู้ใช้งานทั่วไป';
    final deviceId = context.select<SensorProvider, String>((s) => s.selectedDeviceId);
    final devices = context.select<SensorProvider, Map<String, DeviceData>>((s) => s.devices);

    // Only recreate the stream if the deviceId actually changes
    if (_lastDeviceId != deviceId || _postsStream == null) {
      _lastDeviceId = deviceId;
      _postsStream = _dbRef.orderByChild('deviceId').equalTo(deviceId).onValue;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ชุมชนแจ้งเหตุ', style: TextStyle(fontSize: 18)),
            Row(
              children: [
                const Text('อุปกรณ์: ', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: deviceId,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 16),
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        context.read<SensorProvider>().selectDevice(newValue);
                      }
                    },
                    items: devices.values.map((device) {
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
            icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
            onPressed: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedDate = pickedDate;
                });
              }
            },
          ),
        ],
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final isPermissionDenied = snapshot.error.toString().contains('permission-denied');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPermissionDenied ? Icons.lock_person_outlined : Icons.error_outline,
                      size: 64,
                      color: isPermissionDenied ? Colors.orange : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPermissionDenied ? 'จำกัดการเข้าถึงข้อมูลชุมชน' : 'เกิดข้อผิดพลาดในการโหลดข้อมูล',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermissionDenied
                          ? (auth.isGuest || auth.role == 'guest'
                              ? 'คุณกำลังเข้าใช้งานในฐานะผู้เยี่ยมชม กรุณาเข้าสู่ระบบเพื่อเข้าถึงและแบ่งปันข้อมูลเหตุการณ์ในชุมชน'
                              : 'ฐานข้อมูล Firebase ไม่อนุญาตให้เข้าถึง (กรุณาอัปเดตสิทธิ์ Firebase Database Rules)')
                          : snapshot.error.toString(),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (isPermissionDenied && (!auth.isAuthenticated || auth.isGuest || auth.role == 'guest'))
                      ElevatedButton.icon(
                        onPressed: () async {
                          await context.read<AuthProvider>().signOut();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                          }
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('เข้าสู่ระบบ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _postsStream = _dbRef.orderByChild('deviceId').equalTo(deviceId).onValue;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่อีกครั้ง'),
                      ),
                  ],
                ),
              ),
            );
          }

          final event = snapshot.data;
          if (event == null || event.snapshot.value == null) {
            return _buildEmptyState();
          }

          final dataMap = event.snapshot.value as Map<dynamic, dynamic>;
          final List<CommunityPost> posts = dataMap.entries.map((entry) {
            final data = entry.value as Map<dynamic, dynamic>;
            final postKey = entry.key.toString();
            final String? imgUrl = data['imageUrl'];
            Uint8List? bytes;
            if (imgUrl != null && imgUrl.startsWith('data:image')) {
              if (_imageCache.containsKey(postKey)) {
                bytes = _imageCache[postKey];
              } else {
                try {
                  final base64Str = imgUrl.contains(',') ? imgUrl.split(',').last : imgUrl;
                  bytes = base64Decode(base64Str);
                  _imageCache[postKey] = bytes;
                } catch (_) {}
              }
            }
            return CommunityPost(
              key: postKey,
              author: data['author'] ?? 'ไม่ทราบชื่อ',
              location: data['location'] ?? 'ไม่ระบุ',
              description: data['description'] ?? '',
              timestamp: data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              likedBy: (data['likedBy'] as Map<dynamic, dynamic>? ?? {}).map((k, v) => MapEntry(k.toString(), v == true)),
              dislikedBy: (data['dislikedBy'] as Map<dynamic, dynamic>? ?? {}).map((k, v) => MapEntry(k.toString(), v == true)),
              isDanger: data['isDanger'] ?? false,
              deviceId: data['deviceId'] ?? '',
              isReported: data['isReported'] ?? false,
              imageUrl: imgUrl,
              imageBytes: bytes,
            );
          }).toList();

          // Filter by selected date
          List<CommunityPost> filteredPosts = posts;
          if (_selectedDate != null) {
            filteredPosts = posts.where((post) {
              final postDate = DateTime.fromMillisecondsSinceEpoch(post.timestamp);
              return postDate.year == _selectedDate!.year && 
                     postDate.month == _selectedDate!.month && 
                     postDate.day == _selectedDate!.day;
            }).toList();
          }

          // Sort by newest first
          filteredPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (filteredPosts.isEmpty) {
            return Column(
              children: [
                if (_selectedDate != null) _buildFilterHeader(),
                Expanded(child: _buildEmptyState()),
              ],
            );
          }

          return Column(
            children: [
              if (_selectedDate != null) _buildFilterHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    final post = filteredPosts[index];
              return Card(
                key: ValueKey(post.key),
                margin: const EdgeInsets.only(bottom: 16),
                color: Theme.of(context).colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: post.isDanger ? Colors.red.withValues(alpha: 0.5) : Colors.transparent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (post.isReported)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.redAccent,
                        child: const Text('กำลังตรวจสอบรายงานการละเมิด', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Text(post.author.isNotEmpty ? post.author[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(post.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(post.exactTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (post.isDanger)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                child: const Text('ระวังภัย', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (post.imageUrl != null || post.imageBytes != null) ...[
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: EdgeInsets.zero,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      InteractiveViewer(
                                        child: post.imageBytes != null 
                                            ? Image.memory(post.imageBytes!, gaplessPlayback: true)
                                            : Image.network(post.imageUrl!, gaplessPlayback: true),
                                      ),
                                      Positioned(
                                        top: 40,
                                        right: 20,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: post.imageBytes != null 
                                ? Image.memory(
                                    post.imageBytes!,
                                    key: ValueKey('img_${post.key}'),
                                    gaplessPlayback: true,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  )
                                : Image.network(
                                    post.imageUrl!,
                                    key: ValueKey('img_${post.key}'),
                                    gaplessPlayback: true,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 16),
                            const SizedBox(width: 4),
                            Text(post.location, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(post.description, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _toggleLike(post.key, currentUserId, post.likedBy, post.dislikedBy),
                              child: Row(
                                children: [
                                  Icon(
                                    post.likedBy.containsKey(currentUserId) ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                                    color: post.likedBy.containsKey(currentUserId) ? Colors.blueAccent : Colors.grey, 
                                    size: 20
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${post.likesCount}', style: TextStyle(color: post.likedBy.containsKey(currentUserId) ? Colors.blueAccent : Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            InkWell(
                              onTap: () => _toggleDislike(post.key, currentUserId, post.likedBy, post.dislikedBy),
                              child: Row(
                                children: [
                                  Icon(
                                    post.dislikedBy.containsKey(currentUserId) ? Icons.thumb_down : Icons.thumb_down_alt_outlined, 
                                    color: post.dislikedBy.containsKey(currentUserId) ? Colors.redAccent : Colors.grey, 
                                    size: 20
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${post.dislikesCount}', style: TextStyle(color: post.dislikedBy.containsKey(currentUserId) ? Colors.redAccent : Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            InkWell(
                              onTap: () => _showShareBottomSheet(post),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.share_outlined, color: Colors.blueAccent, size: 20),
                                    SizedBox(width: 4),
                                    Text('แชร์', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (currentUserName == post.author)
                              TextButton.icon(
                                onPressed: () => _showDeleteConfirmDialog(post.key),
                                icon: const Icon(Icons.delete, size: 18, color: Colors.grey),
                                label: const Text('ลบโพสต์', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              TextButton.icon(
                                onPressed: () {
                                  _showReportPostDialog(post, auth.displayName);
                                },
                                icon: const Icon(Icons.flag, size: 18, color: Colors.redAccent),
                                label: const Text('รายงาน', style: TextStyle(color: Colors.redAccent)),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
            },
          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReportDialog(deviceId),
        icon: const Icon(Icons.add_alert),
        label: const Text('แจ้งเหตุ'),
        backgroundColor: Colors.orange,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3), // Index 3 is Community
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: Colors.blueAccent.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                'ข้อมูลของวันที่: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year + 543}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
            onPressed: () {
              setState(() {
                _selectedDate = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('ยังไม่มีการแจ้งเหตุในพื้นที่นี้', style: TextStyle(color: Colors.grey, fontSize: 16)),
          Text('กดปุ่มแจ้งเหตุด้านล่างเพื่อเป็นคนแรก', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
