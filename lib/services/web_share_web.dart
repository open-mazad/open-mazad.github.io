// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<bool> systemShare({
  required String title,
  required String text,
  required String url,
}) async {
  try {
    await html.window.navigator.share({
      'title': title,
      'text': text,
      'url': url,
    });
    return true;
  } catch (_) {}
  return false;
}
