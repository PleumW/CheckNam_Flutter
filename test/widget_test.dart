import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/sensor_provider.dart';

void main() {
  test('Smoke test: DeviceData model can be created', () {
    final dev = DeviceData(
      id: 'khlong_1',
      name: 'คลอง 1',
      lat: 13.7563,
      lng: 100.5018,
    );
    expect(dev.id, 'khlong_1');
    expect(dev.name, 'คลอง 1');
  });
}
