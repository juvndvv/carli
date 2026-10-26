import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/core/theme/theme.dart';
import 'package:carli/ui/toast.dart';

import 'fake_api.dart';
import 'finance_app.dart';
import 'test_app.dart';

class Visited extends StatelessWidget {
  const Visited(this.location, {super.key});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Visited $location')));
}

GoRoute visitedRoute(String path) => GoRoute(path: path, builder: (context, state) => Visited(state.uri.toString()));

Future<(ProviderContainer, GoRouter)> pumpRouted(
  WidgetTester tester,
  FakeApi api, {
  required String initialLocation,
  required List<RouteBase> routes,
  bool signedIn = true,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(api, storage: signedIn ? {'auth_token': 'stored'} : const {}, overrides: overrides);
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: carliTheme(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: Stack(children: [child!, const ToastHost()]),
        ),
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);
  return (container, router);
}
