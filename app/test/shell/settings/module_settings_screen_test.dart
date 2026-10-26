import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/modules/modules_provider.dart';
import 'package:carli/shell/settings/module_settings_screen.dart';
import 'package:carli/shell/settings/settings_screen.dart';
import 'package:carli/ui/switch.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/routed_app.dart';
import 'settings_fixtures.dart';

FakeApi modulesApi({int updateStatus = 200}) => FakeApi({
  'GET /v1/me': (_) => (200, {'data': testUser}),
  'GET /v1/modules': (_) => (200, {'data': modulesJson()}),
  'PATCH /v1/modules/finance': (options) => (
    updateStatus,
    updateStatus == 200
        ? {'data': moduleJson(enabled: (options.data as Map)['enabled'] as bool)}
        : {'message': 'Server Error'},
  ),
});

List<RouteBase> moduleRoutes() => [
  GoRoute(path: SettingsPaths.modules, builder: (context, state) => const ModuleSettingsScreen()),
  visitedRoute('/mas/ajustes-finanzas'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists available modules with a switch and upcoming ones as coming soon', (tester) async {
    await pumpFinance(tester, const ModuleSettingsScreen(), modulesApi());

    expect(find.text('Un módulo desactivado desaparece de la navegación. Tus datos se conservan.'), findsOneWidget);
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Próximamente'), findsWidgets);
    expect(find.byType(CarliSwitch), findsOneWidget);
    expect(tester.widget<CarliSwitch>(find.byType(CarliSwitch)).value, isTrue);
  });

  testWidgets('disables a module on the server', (tester) async {
    final api = modulesApi();
    final container = await pumpFinance(tester, const ModuleSettingsScreen(), api);

    await tester.tap(find.byType(CarliSwitch));
    await settle(tester);

    final write = api.requests.singleWhere((request) => request.method == 'PATCH');
    expect(write.path, '/v1/modules/finance');
    expect(write.data, {'enabled': false});
    expect(tester.widget<CarliSwitch>(find.byType(CarliSwitch)).value, isFalse);
    expect(container.read(enabledModuleIdsProvider), isEmpty);
    expect(find.text('Ajustes de Finanzas'), findsNothing);
  });

  testWidgets('reverts the switch and warns when the change fails', (tester) async {
    await pumpFinance(tester, const ModuleSettingsScreen(), modulesApi(updateStatus: 500));

    await tester.tap(find.byType(CarliSwitch));
    await settle(tester);

    expect(tester.widget<CarliSwitch>(find.byType(CarliSwitch)).value, isTrue);
    expect(find.text('No se ha podido cambiar el módulo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('opens the native finance settings', (tester) async {
    await pumpRouted(tester, modulesApi(), initialLocation: SettingsPaths.modules, routes: moduleRoutes());

    await tester.tap(find.text('Ajustes de Finanzas'));
    await settle(tester);

    expect(find.text('Visited /mas/ajustes-finanzas'), findsOneWidget);
  });
}
