import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

final textSharerProvider = Provider<TextSharer>((ref) => const SystemTextSharer());

abstract interface class TextSharer {
  Future<void> share(String text, {String? subject, Rect? origin});
}

class SystemTextSharer implements TextSharer {
  const SystemTextSharer();

  @override
  Future<void> share(String text, {String? subject, Rect? origin}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject, sharePositionOrigin: origin));
}
