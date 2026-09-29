import 'web_notification_helper_stub.dart'
    if (dart.library.js) 'web_notification_helper_web.dart' as helper;

Future<void> initWebNotifications() => helper.initWebNotifications();

bool showWebNotification(String title, String body, {String? icon}) =>
    helper.showWebNotification(title, body, icon: icon);

void playWebSiren(bool play) => helper.playWebSiren(play);
