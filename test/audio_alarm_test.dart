import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/services/audio_alarm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async => null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'soundEnabled': true});
  });

  group('AudioAlarmService Standby and Arming Tests', () {
    test('Initial state: Armed by default, but silent in standby', () {
      final alarm = AudioAlarmService();
      expect(alarm.isAlarmEnabled, isTrue);
      expect(alarm.isPlaying, isFalse);
      expect(alarm.isMuted, isFalse);
    });

    test('Toggling alarm in safe/warning mode toggles armed state without blaring sound', () async {
      final alarm = AudioAlarmService();
      await alarm.setAlarmEnabled(false);
      expect(alarm.isAlarmEnabled, isFalse);
      expect(alarm.isPlaying, isFalse);

      // User turns sound ON in safe/warning mode:
      await alarm.toggleAlarm(isCurrentlyCritical: false);
      expect(alarm.isAlarmEnabled, isTrue);
      // Crucial: Must NOT play sound in safe/warning mode!
      expect(alarm.isPlaying, isFalse);

      // User turns sound OFF:
      await alarm.toggleAlarm(isCurrentlyCritical: false);
      expect(alarm.isAlarmEnabled, isFalse);
      expect(alarm.isPlaying, isFalse);
    });

    test('Disarmed / Muted state prevents siren from starting even when requested', () async {
      final alarm = AudioAlarmService();
      await alarm.mute();
      expect(alarm.isAlarmEnabled, isFalse);

      // Critical event triggers startSiren, but user has muted:
      await alarm.startSiren();
      expect(alarm.isPlaying, isFalse);
    });

    test('Stopping siren in non-critical mode does not disarm user preference', () async {
      final alarm = AudioAlarmService();
      await alarm.setAlarmEnabled(true);
      expect(alarm.isAlarmEnabled, isTrue);

      // Safe state stops siren:
      await alarm.stopSiren();
      expect(alarm.isPlaying, isFalse);
      // Still armed and ready for future critical events!
      expect(alarm.isAlarmEnabled, isTrue);
    });
  });
}
