import 'system_notification_stub.dart'
    if (dart.library.html) 'system_notification_web.dart' as platform_notify;

Future<void> requestNotificationPermission() =>
    platform_notify.requestSystemNotificationPermission();

void triggerSystemNotification({
  required String title,
  required String body,
  String? tag,
}) =>
    platform_notify.showSystemNotification(
      title: title,
      body: body,
      tag: tag,
    );
