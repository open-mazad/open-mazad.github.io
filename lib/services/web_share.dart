import 'web_share_stub.dart'
    if (dart.library.html) 'web_share_web.dart' as platform_share;

Future<bool> systemSharePlatform({
  required String title,
  required String text,
  required String url,
}) =>
    platform_share.systemShare(title: title, text: text, url: url);
