import 'web_geolocation_stub.dart'
    if (dart.library.html) 'web_geolocation_web.dart';

Future<(double, double)?> fetchLiveGpsCoordinates() => getPlatformCoordinates();
