import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

abstract interface class ShareService {
  Future<void> shareText(String text, {String? subject, Rect? origin});
}

class DeviceShareService implements ShareService {
  const DeviceShareService();

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject, sharePositionOrigin: origin));
  }
}
