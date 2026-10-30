import 'package:flutter/material.dart';
import 'live_camera_stub.dart'
    if (dart.library.html) 'live_camera_web.dart';

Widget buildLiveCameraPreview({
  required bool isSeller,
  required bool isFront,
}) {
  return createLiveCameraWidget(
    isSeller: isSeller,
    isFront: isFront,
  );
}
