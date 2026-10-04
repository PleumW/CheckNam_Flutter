import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  group('Device Online / Offline Status Tests', () {
    test('Device is offline when isOnline flag is explicitly false', () {
      final dev = DeviceData(
        id: 'test_1',
        name: 'สถานีทดสอบ',
        lat: 13.75,
        lng: 100.50,
        isOnline: false,
        lastDataReceived: DateTime.now(),
      );

      expect(dev.isDeviceOnline, isFalse);
      expect(dev.onlineStatusText, contains('ออฟไลน์'));
      expect(dev.onlineStatusColor, equals(Colors.redAccent));
      expect(dev.signalPercent, equals(0));
      expect(dev.signalBars, equals(0));
    });

    test('Device is online when lastSeen is within offlineTimeoutSeconds (8s)', () {
      final dev = DeviceData(
        id: 'test_1',
        name: 'สถานีทดสอบ',
        lat: 13.75,
        lng: 100.50,
        isOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(seconds: 4)),
        signalPercent: 85,
      );

      expect(dev.isDeviceOnline, isTrue);
      expect(dev.onlineStatusText, equals('ออนไลน์'));
      expect(dev.onlineStatusColor, equals(Colors.green));
      expect(dev.signalPercent, equals(85));
      expect(dev.signalBars, equals(4));
    });

    test('Device is offline when lastSeen is older than offlineTimeoutSeconds (8s)', () {
      final dev = DeviceData(
        id: 'test_1',
        name: 'สถานีทดสอบ',
        lat: 13.75,
        lng: 100.50,
        isOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(seconds: 10)),
        signalPercent: 85,
      );

      expect(dev.isDeviceOnline, isFalse);
      expect(dev.onlineStatusText, contains('ออฟไลน์'));
      expect(dev.onlineStatusColor, equals(Colors.redAccent));
      expect(dev.signalPercent, equals(0));
      expect(dev.signalBars, equals(0));
    });

    test('Device is online when lastSeen is null but local lastDataReceived is within 8s', () {
      // Simulates real ESP32 that does not transmit timestamp field
      final dev = DeviceData(
        id: 'device_1',
        name: 'ESP32 Station',
        lat: 13.75,
        lng: 100.50,
        isOnline: true,
        lastSeen: null,
        lastDataReceived: DateTime.now().subtract(const Duration(seconds: 3)),
        signalPercent: 70,
      );

      expect(dev.isDeviceOnline, isTrue);
      expect(dev.onlineStatusText, equals('ออนไลน์'));
      expect(dev.onlineStatusColor, equals(Colors.green));
      expect(dev.signalPercent, equals(70));
      expect(dev.signalBars, equals(3));
    });

    test('Device goes offline when lastSeen is null and lastDataReceived expires (>8s)', () {
      // Simulates sensor being unplugged for more than 8s
      final dev = DeviceData(
        id: 'device_1',
        name: 'ESP32 Station',
        lat: 13.75,
        lng: 100.50,
        isOnline: true,
        lastSeen: null,
        lastDataReceived: DateTime.now().subtract(const Duration(seconds: 10)),
        signalPercent: 70,
      );

      expect(dev.isDeviceOnline, isFalse);
      expect(dev.onlineStatusText, contains('ออฟไลน์'));
      expect(dev.onlineStatusColor, equals(Colors.redAccent));
      expect(dev.signalPercent, equals(0));
      expect(dev.signalBars, equals(0));
    });

    test('Device is offline when both lastSeen and lastDataReceived are null (prevent false online on boot)', () {
      final dev = DeviceData(
        id: 'device_unplugged',
        name: 'Unplugged Sensor',
        lat: 13.75,
        lng: 100.50,
        isOnline: true, // Firebase static flag may say true
        lastSeen: null,
        lastDataReceived: null,
      );

      expect(dev.isDeviceOnline, isFalse);
      expect(dev.onlineStatusText, contains('ออฟไลน์'));
    });
  });
}
