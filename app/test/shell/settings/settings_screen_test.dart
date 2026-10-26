import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/shell/settings/settings_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/routed_app.dart';
import 'settings_fixtures.dart';

List<RouteBase> hubRoutes() => [
  GoRoute(path: SettingsPaths.root, builder: (context, state) => const SettingsScreen()),
  visitedRoute(SettingsPaths.profile),
  visitedRoute(SettingsPaths.security),
  visitedRoute(SettingsPaths.notifications),
  visitedRoute(SettingsPaths.modules),
  visitedRoute(SettingsPaths.appearance),
  visitedRoute('/mas/ajustes-finanzas'),
];

FakeApi hubApi({bool financeEnabled = true}) => FakeApi({
  'GET /v1/me': (_) => (200, {'data': testUser}),
  'GET /v1/modules': (_) => (200, {'data': modulesJson(financeEnabled: financeEnabled)}),
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists every settings section with the signed in user', (tester) async {
    await pumpRouted(tester, hubApi(), initialLocation: SettingsPaths.root, routes: hubRoutes());

    expect(find.text('Ajustes'), findsWidgets);
    for (final label in ['Perfil', 'Seguridad', 'Avisos', 'Apariencia', 'Módulos']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('juanda@example.com'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
  });

  for (final (label, path) in [
    ('Perfil', SettingsPaths.profile),
    ('Seguridad', SettingsPaths.security),
    ('Avisos', SettingsPaths.notifications),
    ('Apariencia', SettingsPaths.appearance),
  ]) {
    testWidgets('opens $label', (tester) async {
      await pumpRouted(tester, hubApi(), initialLocation: SettingsPaths.root, routes: hubRoutes());

      await tester.tap(find.text(label));
      await settle(tester);

      expect(find.text('Visited $path'), findsOneWidget);
    });
  }

  testWidgets('opens the module list', (tester) async {
    await pumpRouted(tester, hubApi(), initialLocation: SettingsPaths.root, routes: hubRoutes());

    await tester.tap(find.text('Módulos').last);
    await settle(tester);

    expect(find.text('Visited ${SettingsPaths.modules}'), findsOneWidget);
  });

  testWidgets('links the finance module settings while finance is enabled', (tester) async {
    await pumpRouted(tester, hubApi(), initialLocation: SettingsPaths.root, routes: hubRoutes());

    await tester.tap(find.text('Finanzas'));
    await settle(tester);

    expect(find.text('Visited /mas/ajustes-finanzas'), findsOneWidget);
  });

  testWidgets('hides the finance module settings while finance is disabled', (tester) async {
    await pumpRouted(tester, hubApi(financeEnabled: false), initialLocation: SettingsPaths.root, routes: hubRoutes());

    expect(find.text('Finanzas'), findsNothing);
  });
}
