import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
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

  DateTime? _selectedDate;

  void _showDeleteConfirmDialog(String postKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ลบโพสต์'),
          content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบโพสต์นี้? การลบไม่สามารถเรียกคืนได้'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _dbRef.child(postKey).remove();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบโพสต์สำเร็จ')));
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
    final sensor = context.watch<SensorProvider>();
    final deviceId = sensor.selectedDeviceId;

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
                    items: sensor.devices.values.map((device) {
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
            final String? imgUrl = data['imageUrl'];
            Uint8List? bytes;
            if (imgUrl != null && imgUrl.startsWith('data:image')) {
              try {
                final base64Str = imgUrl.contains(',') ? imgUrl.split(',').last : imgUrl;
                bytes = base64Decode(base64Str);
              } catch (_) {}
            }
            return CommunityPost(
              key: entry.key.toString(),
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
                                            ? Image.memory(post.imageBytes!)
                                            : Image.network(post.imageUrl!),
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
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  )
                                : Image.network(
                                    post.imageUrl!,
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
