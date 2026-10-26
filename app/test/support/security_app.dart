import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:carli/core/auth/biometric_lock.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/shell/settings/security/data/text_sharer.dart';
import 'package:carli/ui/toast.dart';

import 'fake_api.dart';
import 'test_app.dart';

class FakeLocalAuthentication implements LocalAuthentication {
  FakeLocalAuthentication({this.supported = true, this.passes = true, this.types = const [BiometricType.face]});

  final bool supported;
  final bool passes;
  final List<BiometricType> types;
  var authentications = 0;

  @override
  Future<bool> get canCheckBiometrics async => supported;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => supported ? types : const [];

  @override
  Future<bool> stopAuthentication() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      authentications++;
      return Future.value(passes);
    }
    return super.noSuchMethod(invocation);
  }
}

class RecordingTextSharer implements TextSharer {
  final List<String> shared = [];

  @override
  Future<void> share(String text, {String? subject, Rect? origin}) async => shared.add(text);
}

Future<ProviderContainer> pumpSecurityScreen(
  WidgetTester tester,
  Widget screen,
  FakeApi api, {
  FakeLocalAuthentication? localAuth,
  TextSharer? sharer,
  Map<String, String> storage = const {},
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(402 * 3, 2600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(
    api,
    storage: {'auth_token': 'stored', ...storage},
    overrides: [
      localAuthProvider.overrideWithValue(localAuth ?? FakeLocalAuthentication()),
      textSharerProvider.overrideWithValue(sharer ?? RecordingTextSharer()),
      ...overrides,
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: carliTheme(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: Stack(children: [child!, const ToastHost()]),
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
