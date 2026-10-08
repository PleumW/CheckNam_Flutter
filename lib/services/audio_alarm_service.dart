import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_notification_helper.dart';

/// บริการจัดการเสียงไซเรนเตือนภัยฉุกเฉิน (Emergency Alarm Audio Service)
class AudioAlarmService with ChangeNotifier {
  static final AudioAlarmService _instance = AudioAlarmService._internal();
  factory AudioAlarmService() => _instance;
  AudioAlarmService._internal() {
    _loadPreference();
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isAlarmEnabled = true; // เปิดใช้งานระบบเสียงเตือนภัยเป็นค่าเริ่มต้น (Armed by default)
  Timer? _hapticTimer;

  bool get isPlaying => _isPlaying;
  bool get isAlarmEnabled => _isAlarmEnabled;
  bool get isMuted => !_isAlarmEnabled;

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('soundEnabled')) {
        _isAlarmEnabled = prefs.getBool('soundEnabled') ?? true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _savePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundEnabled', _isAlarmEnabled);
    } catch (_) {}
  }

  /// ตั้งค่าเปิด/ปิดระบบเสียงเตือนภัย (Arm / Disarm)
  Future<void> setAlarmEnabled(bool enabled, {bool isCurrentlyCritical = false}) async {
    _isAlarmEnabled = enabled;
    await _savePreference();
    if (!enabled) {
      await stopSiren();
    } else if (isCurrentlyCritical) {
      await startSiren();
    }
    notifyListeners();
  }

  /// สลับสถานะเปิด/ปิดระบบเสียงเตือนภัย
  /// - หากเปิดค้างไว้: ตอนปลอดภัยและเฝ้าระวังจะยังไม่ดัง จะดังเฉพาะเมื่อสถานการณ์วิกฤตเท่านั้น
  /// - หากกดปิด: ระบบจะปิดเสียงเตือนทั้งหมด แม้ถึงระดับวิกฤตก็จะไม่ส่งเสียง
  Future<void> toggleAlarm({bool isCurrentlyCritical = false}) async {
    if (_isPlaying) {
      // หากเสียงไซเรนกำลังดังอยู่ กดเพื่อปิดเสียงทันที
      await mute();
    } else if (_isAlarmEnabled) {
      // หากเปิดระบบทิ้งไว้ (สแตนด์บาย) กดเพื่อปิดเสียง
      await mute();
    } else {
      // หากปิดอยู่ กดเพื่อเปิดระบบเสียงค้างไว้
      _isAlarmEnabled = true;
      await _savePreference();
      notifyListeners();
      if (isCurrentlyCritical) {
        await startSiren();
      }
    }
  }

  /// ปิดเสียง (Mute / Disarm)
  Future<void> mute() async {
    _isAlarmEnabled = false;
    await _savePreference();
    await stopSiren();
    notifyListeners();
  }

  /// รีเซ็ตสถานะการ Mute เมื่อผู้ใช้ต้องการเปิดเสียงใหม่ (Unmute / Arm)
  Future<void> resetMute({bool isCurrentlyCritical = false}) async {
    _isAlarmEnabled = true;
    await _savePreference();
    notifyListeners();
    if (isCurrentlyCritical) {
      await startSiren();
    }
  }

  /// เริ่มเล่นเสียงไซเรนฉุกเฉินเตือนภัย (Looping Siren & Haptics)
  /// จะเริ่มเล่นได้ก็ต่อเมื่อ _isAlarmEnabled == true เท่านั้น
  Future<void> startSiren() async {
    if (!_isAlarmEnabled || _isPlaying) return;

    try {
      _isPlaying = true;
      notifyListeners();

      if (kIsWeb) {
        playWebSiren(true);
      }

      if (!kIsWeb) {
        try {
          await _player.setAudioContext(
            AudioContext(
              android: const AudioContextAndroid(
                isSpeakerphoneOn: true,
                stayAwake: true,
                contentType: AndroidContentType.sonification,
                usageType: AndroidUsageType.alarm,
                audioFocus: AndroidAudioFocus.gainTransientExclusive,
              ),
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
                options: {
                  AVAudioSessionOptions.duckOthers,
                  AVAudioSessionOptions.defaultToSpeaker,
                },
              ),
            ),
          );
        } catch (e) {
          debugPrint('[AudioAlarmService] AudioContext config error: $e');
        }
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

  /// เล่นเสียงไซเรนทดสอบชั่วคราว (เช่น 3 วินาที) เพื่อตรวจสอบลำโพงและระดับเสียง
  Future<void> playTestSiren({Duration duration = const Duration(seconds: 3)}) async {
    final prevEnabled = _isAlarmEnabled;
    _isAlarmEnabled = true;
    await startSiren();
    Timer(duration, () async {
      await stopSiren();
      _isAlarmEnabled = prevEnabled;
      notifyListeners();
    });
  }

  /// หยุดเสียงไซเรน (แต่ยังคงจำสถานะ _isAlarmEnabled ตามที่ผู้ใช้เปิดไว้)
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

  void disposePlayer() {
    if (kIsWeb) {
      playWebSiren(false);
    }
    _hapticTimer?.cancel();
    _player.dispose();
  }
}
