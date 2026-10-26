import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/core/router/router.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/screens/settings/finance_settings_screen.dart';
import 'package:carli/ui/toast.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';
import '../../../support/test_app.dart';

final now = DateTime(2026, 10, 26, 10);

Json settingsJson({int threshold = 80, String mode = 'payroll', int minDays = 20, String? defaultAccount}) => {
  'default_account_id': defaultAccount,
  'last_used_account_id': 'acc-main',
  'budget_warning_threshold': threshold,
  'period_min_days': minDays,
  'period_mode': mode,
  'remind_days_before': 2,
};

Map<String, FakeRoute> settingsRoutes({bool periodsChanged = false}) => {
  ...financeBaseRoutes(),
  'GET /v1/finance/categories': (_) => (
    200,
    {
      'data': [
        categoryJson('cat-food', 'Comida', icon: 'utensils'),
        {...categoryJson('payroll', 'Nómina', kind: 'income', icon: 'wallet'), 'opens_period': true},
        {...categoryJson('extra', 'Extra', kind: 'income'), 'opens_period': false},
      ],
    },
  ),
  'PATCH /v1/finance/settings': (options) => (
    200,
    {
      'data': {...settingsJson(), ...options.data as Json},
      'meta': {'periods_changed': periodsChanged},
    },
  ),
};

Json lastBody(FakeApi api, String method, String path) =>
    api.requests.lastWhere((request) => request.method == method && request.path == path).data as Json;

Finder labelled(String label) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final page = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(finder, 300, scrollable: page);
  await tester.drag(page, const Offset(0, -200));
  await tester.pumpAndSettle();
}

Future<void> pumpSettings(WidgetTester tester, FakeApi api) =>
    pumpFinance(tester, FinanceSettingsScreen(now: now), api);

void main() {
  testWidgets('shows the current settings, the opening categories and recent periods', (tester) async {
    await pumpSettings(tester, FakeApi(settingsRoutes()));

    expect(find.text('Ajustes de Finanzas'), findsWidgets);
    expect(find.text('La última usada'), findsOneWidget);
    expect(find.widgetWithText(TextField, '80'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '20'), findsOneWidget);
    expect(
      find.text('Cada periodo empieza el día que registras la nómina y termina el día antes de la siguiente.'),
      findsOneWidget,
    );

    await reveal(tester, find.text('Extra'));
    expect(find.text('Bancos y reglas'), findsOneWidget);
    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);

    await reveal(tester, find.text('Septiembre'));
    expect(find.text('Octubre'), findsOneWidget);
    expect(find.text('26 sep – 27 oct · queda 1 día'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('Por nómina'), findsOneWidget);
  });

  testWidgets('saves the general settings', (tester) async {
    final api = FakeApi(settingsRoutes());
    await pumpSettings(tester, api);

    await tester.enterText(find.widgetWithText(TextField, '80'), '90');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(lastBody(api, 'PATCH', '/v1/finance/settings'), {
      'default_account_id': null,
      'budget_warning_threshold': 90,
      'remind_days_before': 2,
      'period_mode': 'payroll',
      'period_min_days': 20,
    });
    expect(find.text('Ajustes guardados'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('switches to calendar months and announces the recalculated periods', (tester) async {
    final api = FakeApi(settingsRoutes(periodsChanged: true));
    await pumpSettings(tester, api);
    final periodRequests = api.requests.where((request) => request.path == '/v1/finance/periods').length;

    await tester.tap(find.text('Mes natural'));
    await tester.pump();
    expect(find.text('Cada periodo va del día 1 al último día del mes.'), findsOneWidget);
    expect(find.text('Días mínimos entre nóminas'), findsNothing);

    await tester.tap(find.text('La última usada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BBVA').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await settle(tester);

    final body = lastBody(api, 'PATCH', '/v1/finance/settings');
    expect(body['period_mode'], 'calendar');
    expect(body['default_account_id'], 'acc-main');
    expect(find.text('Ajustes guardados · periodos recalculados'), findsOneWidget);
    expect(api.requests.where((request) => request.path == '/v1/finance/periods').length, greaterThan(periodRequests));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('validates the ranges and shows the server errors', (tester) async {
    final api = FakeApi({
      ...settingsRoutes(),
      'PATCH /v1/finance/settings': (_) => (
        422,
        {
          'message': 'invalid',
          'errors': {
            'remind_days_before': ['Demasiados días.'],
          },
        },
      ),
    });
    await pumpSettings(tester, api);

    await tester.enterText(find.widgetWithText(TextField, '80'), '150');
    await tester.pump();
    expect(find.text('Entre 1 y 100.'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(api.requests.where((request) => request.method == 'PATCH'), isEmpty);

    await tester.enterText(find.widgetWithText(TextField, '150'), '85');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(find.text('Demasiados días.'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('toggles which income categories open a period', (tester) async {
    final api = FakeApi({
      ...settingsRoutes(),
      'PATCH /v1/finance/categories/extra': (_) => (200, {'data': {}}),
    });
    await pumpSettings(tester, api);

    await reveal(tester, labelled('Abre periodo: Extra'));
    await tester.tap(find.descendant(of: labelled('Abre periodo: Extra'), matching: find.byType(CupertinoSwitch)));
    await settle(tester);

    expect(lastBody(api, 'PATCH', '/v1/finance/categories/extra'), {'opens_period': true});
    expect(find.text('Extra abrirá periodo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('moves the start of a period', (tester) async {
    final api = FakeApi({
      ...settingsRoutes(),
      'PATCH /v1/finance/periods/p-oct': (options) => (200, {'data': periodJson()}),
    });
    await pumpSettings(tester, api);

    await reveal(tester, labelled('Mover el inicio del Octubre'));
    await tester.tap(labelled('Mover el inicio del Octubre'));
    await tester.pumpAndSettle();
    expect(find.text('Mover inicio del periodo'), findsOneWidget);
    expect(find.text('Octubre. El periodo anterior se ajusta para terminar el día antes.'), findsOneWidget);

    await tester.tap(find.text('28'));
    await tester.pump();
    await tester.tap(find.text('Mover inicio'));
    await tester.pumpAndSettle();

    expect(lastBody(api, 'PATCH', '/v1/finance/periods/p-oct'), {'start_date': '2026-09-28'});
    expect(find.text('Inicio del periodo actualizado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('opens a period by hand', (tester) async {
    final api = FakeApi({
      ...settingsRoutes(),
      'POST /v1/finance/periods': (_) => (201, {'data': periodJson(id: 'p-nov', name: 'Periodo de noviembre')}),
    });
    await pumpSettings(tester, api);

    await reveal(tester, find.text('Abrir periodo'));
    await tester.tap(find.text('Abrir periodo'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir periodo a mano'), findsOneWidget);

    await tester.tap(find.text('Abrir periodo').last);
    await tester.pumpAndSettle();

    expect(lastBody(api, 'POST', '/v1/finance/periods'), {'start_date': '2026-10-26'});
    expect(find.text('Abierto el periodo de noviembre'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('links to the bank connections', (tester) async {
    final api = FakeApi(settingsRoutes());
    final container = testContainer(api, storage: {'auth_token': 'stored'});
    final router = GoRouter(
      initialLocation: Routes.financeSettings,
      routes: [
        GoRoute(
          path: Routes.financeSettings,
          builder: (context, state) => FinanceSettingsScreen(now: now),
          routes: [GoRoute(path: 'bancos', builder: (context, state) => const Text('Pantalla de bancos'))],
        ),
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
          builder: (context, child) => Material(
            type: MaterialType.transparency,
            child: Stack(children: [child!, const ToastHost()]),
          ),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Bancos y reglas'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Bancos y reglas'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.banks);
    expect(find.text('Pantalla de bancos'), findsOneWidget);
  });
}
