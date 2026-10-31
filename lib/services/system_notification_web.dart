// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> requestSystemNotificationPermission() async {
  try {
    if (html.Notification.supported &&
        html.Notification.permission != 'granted' &&
        html.Notification.permission != 'denied') {
      await html.Notification.requestPermission();
    }
  } catch (_) {}
}

void showSystemNotification({
  required String title,
  required String body,
  String? tag,
}) {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: 'icons/Icon-192.png',
        tag: tag,
      );
    }
  } catch (_) {}
}
