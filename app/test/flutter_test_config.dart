import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final geist = File('assets/fonts/Geist-Variable.ttf').readAsBytesSync();
  // SF Pro is not available off Apple platforms: Geist stands in for the system font aliases so
  // layouts are measured with real glyph widths instead of the square test font.
  for (final family in ['Geist', 'CupertinoSystemText', 'CupertinoSystemDisplay']) {
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(geist)))).load();
  }
  await testMain();
}
