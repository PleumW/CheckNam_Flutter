// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

Future<void> initWebNotifications() async {
  try {
    js.context.callMethod('requestWebNotificationPermission');
  } catch (_) {}
}

bool showWebNotification(String title, String body, {String? icon}) {
  try {
    final res = js.context.callMethod('showWebNotification', [
      title,
      body,
      icon ?? 'icons/Icon-192.png',
    ]);
    return res == true;
  } catch (_) {
    return false;
  }
}

void playWebSiren(bool play) {
  try {
    js.context.callMethod('playWebSirenSound', [play]);
  } catch (_) {}
}
