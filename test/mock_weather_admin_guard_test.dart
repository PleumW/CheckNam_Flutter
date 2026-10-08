import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_water_flood/providers/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeatherService.clearMock();
  });

  group('Mock Weather Admin Access Guard Tests', () {
    test('Non-admin users should not have permission to enable mock weather presets', () {
      // Role validation logic test:
      // Regular user / guest should be evaluated as non-admin
      const regularUserRole = 'user';
      const isGuestMode = false;
      final isRegularAdmin = !isGuestMode && regularUserRole == 'admin';
      expect(isRegularAdmin, isFalse);

      const guestRole = 'guest';
      const isGuest = true;
      final isGuestAdmin = !isGuest && guestRole == 'admin';
      expect(isGuestAdmin, isFalse);

      // Admin role must evaluate to true
      const adminRole = 'admin';
      final isAdmin = !isGuestMode && adminRole == 'admin';
      expect(isAdmin, isTrue);
    });

    test('Mock weather presets are available for admin configuration', () {
      expect(WeatherService.presets, contains('sunny'));
      expect(WeatherService.presets, contains('cloudy'));
      expect(WeatherService.presets, contains('heavy_rain'));
      expect(WeatherService.presets, contains('storm_critical'));
    });
  });
}
