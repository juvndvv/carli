import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/theme/theme.dart';
import 'package:carli/ui/toast.dart';

import 'fake_api.dart';
import 'test_app.dart';

Future<ProviderContainer> pumpFinance(WidgetTester tester, Widget screen, FakeApi api) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(api, storage: {'auth_token': 'stored'});
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
  await settle(tester);
  return container;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
