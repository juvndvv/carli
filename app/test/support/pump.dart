import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/theme/theme.dart';

Future<void> pumpUi(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: carliTheme(brightness),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: SafeArea(child: child)),
      ),
    ),
  );
}
