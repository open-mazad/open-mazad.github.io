// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget createLiveCameraWidget({
  required bool isSeller,
  required bool isFront,
}) {
  return _WebCameraView(isSeller: isSeller, isFront: isFront);
}

class _WebCameraView extends StatefulWidget {
  final bool isSeller;
  final bool isFront;
  const _WebCameraView({required this.isSeller, required this.isFront});

  @override
  State<_WebCameraView> createState() => _WebCameraViewState();
}

class _WebCameraViewState extends State<_WebCameraView> {
  static int _counter = 0;
  late final String _viewType;
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'live-camera-${_counter++}';
    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
    _video = video;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => video,
    );

    if (widget.isSeller) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': widget.isFront ? 'user' : 'environment',
        },
        'audio': false,
      });
      _stream = stream;
      if (_video != null && stream != null) {
        _video!.srcObject = stream;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void didUpdateWidget(covariant _WebCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFront != widget.isFront && widget.isSeller) {
      _stream?.getTracks().forEach((t) => t.stop());
      _initCamera();
    }
  }

  @override
  void dispose() {
    _stream?.getTracks().forEach((t) => t.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSeller) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv, size: 72, color: Colors.white38),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 56, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'يرجى إعطاء المتصفح إذن تشغيل الكاميرا لبدء البث المباشر:\n$_error',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return HtmlElementView(viewType: _viewType);
  }
}
