// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<(double, double)?> getPlatformCoordinates() async {
  try {
    final geo = html.window.navigator.geolocation;
    // أولاً: تجربة جلب الموقع السريع (Wi-Fi / الشبكة) لتفادي التعليق في متصفحات سطح المكتب
    try {
      final pos = await geo.getCurrentPosition(
        enableHighAccuracy: false,
        timeout: const Duration(seconds: 8),
        maximumAge: const Duration(minutes: 5),
      );
      final coords = pos.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        return (coords.latitude!.toDouble(), coords.longitude!.toDouble());
      }
    } catch (_) {
      // ثانياً: المحاولة بدقة عالية (GPS) للهواتف والأجهزة الداعمة
      final pos = await geo.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(seconds: 10),
      );
      final coords = pos.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        return (coords.latitude!.toDouble(), coords.longitude!.toDouble());
      }
    }
  } catch (_) {}
  return null;
}
