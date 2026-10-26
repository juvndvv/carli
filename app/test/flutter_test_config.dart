import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final geist = File('assets/fonts/Geist-Variable.ttf').readAsBytesSync();
  await (FontLoader('Geist')..addFont(Future.value(ByteData.sublistView(geist)))).load();
  await testMain();
}
