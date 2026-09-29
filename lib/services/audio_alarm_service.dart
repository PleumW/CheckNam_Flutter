import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'web_notification_helper.dart';

/// บริการจัดการเสียงไซเรนเตือนภัยฉุกเฉิน (Emergency Alarm Audio Service)
class AudioAlarmService with ChangeNotifier {
  static final AudioAlarmService _instance = AudioAlarmService._internal();
  factory AudioAlarmService() => _instance;
  AudioAlarmService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isMuted = false;
  Timer? _hapticTimer;

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  /// เริ่มเล่นเสียงไซเรนฉุกเฉินเตือนภัย (Looping Siren & Haptics)
  Future<void> startSiren() async {
    if (_isMuted || _isPlaying) return;

    try {
      _isPlaying = true;
      notifyListeners();

      if (kIsWeb) {
        playWebSiren(true);
      }

      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/siren.wav'));

      if (!kIsWeb) {
        // Periodic vibration haptic feedback
        _hapticTimer?.cancel();
        _hapticTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
          HapticFeedback.heavyImpact();
        });
      }
    } catch (e) {
      debugPrint('[AudioAlarmService] Error playing siren audio: $e');
      if (kIsWeb) {
        playWebSiren(true);
      }
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// หยุดเสียงไซเรน
  Future<void> stopSiren() async {
    if (!_isPlaying) return;

    try {
      if (kIsWeb) {
        playWebSiren(false);
      }
      _hapticTimer?.cancel();
      _hapticTimer = null;
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioAlarmService] Error stopping siren: $e');
    } finally {
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// ปิดเสียงชั่วคราว (Mute)
  Future<void> mute() async {
    _isMuted = true;
    await stopSiren();
    notifyListeners();
  }

  /// รีเซ็ตสถานะการ Mute เมื่อเหตุการณ์คลี่คลาย
  void resetMute() {
    _isMuted = false;
    notifyListeners();
  }

  void disposePlayer() {
    if (kIsWeb) {
      playWebSiren(false);
    }
    _hapticTimer?.cancel();
    _player.dispose();
  }
}
