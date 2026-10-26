import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/core/router/router.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/shell/pending/pending_screen.dart';
import 'package:carli/ui/toast.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/test_app.dart';

const pendingPath = '/pendientes';

Future<({GoRouter router, ProviderContainer container})> pumpPendingRouter(
  WidgetTester tester,
  FakeApi api, {
  String location = pendingPath,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(api, storage: {'auth_token': 'stored'}, overrides: overrides);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: pendingPath,
        builder: (context, state) =>
            PendingScreen(module: state.uri.queryParameters['modulo'], type: state.uri.queryParameters['tipo']),
      ),
      GoRoute(path: Routes.recurring, builder: (context, state) => const Text('Pantalla de recurrentes')),
      GoRoute(path: Routes.transactions, builder: (context, state) => const Text('Pantalla de movimientos')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: carliTheme(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: Stack(children: [child!, const ToastHost()]),
        ),
      ),
    ),
  );
  await settle(tester);
  return (router: router, container: container);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 11));
}
