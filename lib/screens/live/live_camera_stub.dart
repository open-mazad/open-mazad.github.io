import 'package:flutter/material.dart';

Widget createLiveCameraWidget({
  required bool isSeller,
  required bool isFront,
}) {
  return Container(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSeller ? Icons.videocam : Icons.live_tv,
              size: 72, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            isSeller ? 'أنت تبث الآن للمشترين 🔴' : 'بث مباشر 🔴',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}
