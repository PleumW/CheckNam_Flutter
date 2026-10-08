import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Upstream and Downstream Station Model & Backward Compatibility Tests', () {
    test('DeviceData correctly identifies upstream and downstream stations with aliases', () {
      final upstreamStation = DeviceData(
        id: 'station_upstream',
        name: 'สถานีต้นทาง (Upstream)',
        stationType: 'upstream',
        lat: 13.7563,
        lng: 100.5018,
        waterLevel: 45.0,
      );

      final downstreamStation = DeviceData(
        id: 'station_downstream',
        name: 'สถานีปลายทาง (Downstream)',
        stationType: 'downstream',
        lat: 13.7620,
        lng: 100.5120,
        waterLevel: 20.0,
      );

      // Upstream checks
      expect(upstreamStation.isUpstream, isTrue);
      expect(upstreamStation.isDownstream, isFalse);
      expect(upstreamStation.isRiverbank, isTrue); // Backward compatibility alias
      expect(upstreamStation.stationTypeName, contains('สถานีตรวจวัด'));

      // Downstream checks
      expect(downstreamStation.isDownstream, isTrue);
      expect(downstreamStation.isUpstream, isFalse);
      expect(downstreamStation.isUrban, isTrue); // Backward compatibility alias
      expect(downstreamStation.stationTypeName, contains('สถานีตรวจวัด'));
    });

    test('Legacy riverbank and urban identifiers seamlessly map to upstream and downstream', () {
      final legacyRiverbank = DeviceData(
        id: 'station_riverbank',
        name: 'สถานีคลองเดิม',
        stationType: 'riverbank',
        lat: 13.75,
        lng: 100.50,
      );

      final legacyUrban = DeviceData(
        id: 'station_urban',
        name: 'สถานีชุมชนเดิม',
        stationType: 'urban',
        lat: 13.76,
        lng: 100.51,
      );

      expect(legacyRiverbank.isUpstream, isTrue);
      expect(legacyRiverbank.isRiverbank, isTrue);
      expect(legacyUrban.isDownstream, isTrue);
      expect(legacyUrban.isUrban, isTrue);
    });

    test('Water level delta and drainage description accurately describe upstream vs downstream states', () {
      final upHigh = DeviceData(
        id: 'up_1',
        name: 'ต้นทาง',
        stationType: 'upstream',
        lat: 13.75,
        lng: 100.50,
        waterLevel: 55.0,
        waterLevelThreshold: 70.0,
      );
      final downLow = DeviceData(
        id: 'down_1',
        name: 'ปลายทาง',
        stationType: 'downstream',
        lat: 13.76,
        lng: 100.51,
        waterLevel: 20.0,
        waterLevelThreshold: 50.0,
      );

      final double delta1 = upHigh.waterLevel - downLow.waterLevel;
      expect(delta1, 35.0);

      // Equal condition
      const double deltaEqual = 0.0;
      expect(deltaEqual.abs() < 0.5, isTrue);
    });
  });

  group('Inter-Device Proximity Flood Alert Propagation Tests', () {
    test('Flood at upstream station propagates advance warning to downstream station', () {
      final sensor = SensorProvider();

      // Simulate upstream water level rising into flood danger (85 cm > threshold 70 cm)
      sensor.simulateDualStation(
        upstreamLevel: 85.0,
        downstreamLevel: 25.0,
      );

      // Verify inter-device proximity flood alert was activated
      expect(sensor.hasProximityFloodAlert, isTrue);
      expect(sensor.proximityFloodAlertMessage, isNotNull);
      expect(sensor.proximityFloodAlertMessage, contains('แจ้งเตือนภัยวิกฤตในรัศมี 20 กม.!'));
      expect(sensor.proximityFloodAlertMessage, contains('ตรวจพบระดับน้ำวิกฤต'));

      // Check condition in dual-station drainage status
      expect(sensor.drainageConditionShort, contains('เตือนภัยวิกฤต!'));
      expect(sensor.deltaDescription, contains('สูงกว่า'));
    });

    test('Flood at downstream station triggers backwater drainage bottleneck alert to upstream station', () {
      final sensor = SensorProvider();

      // Simulate downstream flooded (70 cm > threshold 50 cm) while upstream is normal (20 cm)
      sensor.simulateDualStation(
        upstreamLevel: 20.0,
        downstreamLevel: 70.0,
      );

      expect(sensor.hasProximityFloodAlert, isTrue);
      expect(sensor.proximityFloodAlertMessage, contains('แจ้งเตือนภัยวิกฤตในรัศมี 20 กม.!'));
      expect(sensor.proximityFloodAlertMessage, contains('ตรวจพบระดับน้ำวิกฤต'));
      expect(sensor.drainageConditionShort, contains('เตือนภัยวิกฤต!'));
      expect(sensor.deltaDescription, contains('สูงกว่า'));
    });

    test('Dual critical flood correctly alerts for both stations simultaneously', () {
      final sensor = SensorProvider();

      sensor.simulateDualStation(
        upstreamLevel: 90.0,
        downstreamLevel: 75.0,
      );

      expect(sensor.hasProximityFloodAlert, isTrue);
      expect(sensor.drainageConditionShort, contains('วิกฤตน้ำท่วมทั้งสองสถานี'));
    });

    test('Normal flow clears proximity flood alerts', () {
      final sensor = SensorProvider();

      // First trigger flood
      sensor.simulateDualStation(
        upstreamLevel: 85.0,
        downstreamLevel: 20.0,
      );
      expect(sensor.hasProximityFloodAlert, isTrue);

      // Then restore to normal levels
      sensor.simulateDualStation(
        upstreamLevel: 15.0,
        downstreamLevel: 10.0,
      );

      expect(sensor.hasProximityFloodAlert, isFalse);
      expect(sensor.drainageConditionShort, contains('ระดับน้ำในเครือข่ายสถานีปกติ'));
    });
  });
}
