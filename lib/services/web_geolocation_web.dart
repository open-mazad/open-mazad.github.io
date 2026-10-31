// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<(double, double)?> getPlatformCoordinates() async {
  try {
    final geo = html.window.navigator.geolocation;
    final pos = await geo.getCurrentPosition();
    final coords = pos.coords;
    if (coords != null && coords.latitude != null && coords.longitude != null) {
      return (coords.latitude!.toDouble(), coords.longitude!.toDouble());
    }
  } catch (_) {}
  return null;
}
