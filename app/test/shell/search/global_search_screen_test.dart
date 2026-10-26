import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/modules/finance/data/transaction_filters.dart';
import 'package:carli/shell/search/global_search_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';
import '../../support/routed_app.dart';
import '../settings/settings_fixtures.dart';

const searchPath = '/buscar';

Map<String, Object?> resultJson({
  String type = 'account',
  String id = 'acc-1',
  String title = 'BBVA Nómina',
  String? subtitle = '1.250,00 €',
  String url = '/finanzas/cuentas/acc-1',
  String icon = 'landmark',
}) => {
  'module': 'finance',
  'module_name': 'Finanzas',
  'type': type,
  'id': id,
  'title': title,
  'subtitle': subtitle,
  'url': url,
  'icon': icon,
};

FakeApi searchApi({List<Map<String, Object?>>? results, Map<String, FakeRoute> extra = const {}}) => FakeApi({
  'GET /v1/me': (_) => (200, {'data': testUser}),
  'GET /v1/modules': (_) => (200, {'data': modulesJson()}),
  'GET /v1/search': (_) => (
    200,
    {
      'data': results ?? [resultJson()],
    },
  ),
  ...extra,
});

List<RouteBase> searchRoutes() => [
  GoRoute(path: searchPath, builder: (context, state) => const GlobalSearchScreen()),
  visitedRoute('/'),
  visitedRoute('/finanzas/movimientos'),
  visitedRoute('/mas/cuentas/:id'),
  visitedRoute('/mas/categorias'),
];

Iterable<String?> searchQueries(FakeApi api) => [
  for (final request in api.requests)
    if (request.path == '/v1/search') request.queryParameters['q'] as String?,
];

Future<void> typeQuery(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('suggests sections and asks for two letters before searching', (tester) async {
    final api = searchApi();
    await pumpRouted(tester, api, initialLocation: searchPath, routes: searchRoutes());

    expect(find.text('Buscar'), findsWidgets);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Secciones'), findsOneWidget);

    await typeQuery(tester, 'x');
    await settle(tester);

    expect(find.text('Escribe al menos 2 letras.'), findsOneWidget);
    expect(searchQueries(api), isEmpty);
  });

  testWidgets('debounces the query and groups the results by module', (tester) async {
    final api = searchApi(
      results: [
        resultJson(),
        resultJson(
          type: 'transaction',
          id: 'tx-1',
          title: 'Mercadona',
          subtitle: '-42,50 € · 3 oct',
          url: '/finanzas/movimientos?q=bb',
        ),
      ],
    );
    await pumpRouted(tester, api, initialLocation: searchPath, routes: searchRoutes());

    await typeQuery(tester, 'b');
    await typeQuery(tester, 'bb');
    expect(find.text('Buscando…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(searchQueries(api), isEmpty);
    await tester.pump(searchDebounce);
    await settle(tester);

    expect(searchQueries(api), ['bb']);
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('BBVA Nómina'), findsOneWidget);
    expect(find.text('Mercadona'), findsOneWidget);
  });

  testWidgets('reports a query without results', (tester) async {
    await pumpRouted(
      tester,
      searchApi(results: []),
      initialLocation: searchPath,
      routes: searchRoutes(),
    );

    await typeQuery(tester, 'zzz');
    await tester.pump(searchDebounce);
    await settle(tester);

    expect(find.text('Sin resultados para «zzz».'), findsOneWidget);
  });

  testWidgets('treats a failed search as no results', (tester) async {
    final api = searchApi(
      extra: {
        'GET /v1/search': (_) => (500, {'message': 'Server Error'}),
      },
    );
    await pumpRouted(tester, api, initialLocation: searchPath, routes: searchRoutes());

    await typeQuery(tester, 'zzz');
    await tester.pump(searchDebounce);
    await settle(tester);

    expect(find.text('Sin resultados para «zzz».'), findsOneWidget);
  });

  testWidgets('opens an account result at its native route', (tester) async {
    await pumpRouted(tester, searchApi(), initialLocation: searchPath, routes: searchRoutes());

    await typeQuery(tester, 'bbva');
    await tester.pump(searchDebounce);
    await settle(tester);
    await tester.tap(find.text('BBVA Nómina'));
    await settle(tester);

    expect(find.text('Visited /mas/cuentas/acc-1'), findsOneWidget);
  });

  testWidgets('opens a matching section without waiting for the server', (tester) async {
    await pumpRouted(
      tester,
      searchApi(results: []),
      initialLocation: searchPath,
      routes: searchRoutes(),
    );

    await typeQuery(tester, 'categor');
    await tester.tap(find.text('Categorías'));
    await settle(tester);

    expect(find.text('Visited /mas/categorias'), findsOneWidget);
  });

  testWidgets('opens a transaction result in the edit sheet', (tester) async {
    final api = searchApi(
      results: [resultJson(type: 'transaction', id: 'tx-1', title: 'Mercadona', url: '/finanzas/movimientos?q=merca')],
      extra: {
        ...financeBaseRoutes(),
        'GET /v1/finance/transactions/tx-1': (_) => (200, {'data': transactionJson()}),
      },
    );
    await pumpRouted(tester, api, initialLocation: searchPath, routes: searchRoutes());

    await typeQuery(tester, 'merca');
    await tester.pump(searchDebounce);
    await settle(tester);
    await tester.tap(find.text('Mercadona'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('Editar movimiento'), findsOneWidget);
  });

  testWidgets('falls back to the filtered transactions when the transaction cannot be loaded', (tester) async {
    final api = searchApi(
      results: [resultJson(type: 'transaction', id: 'tx-9', title: 'Mercadona', url: '/finanzas/movimientos?q=merca')],
    );
    final (container, _) = await pumpRouted(tester, api, initialLocation: searchPath, routes: searchRoutes());

    await typeQuery(tester, 'merca');
    await tester.pump(searchDebounce);
    await settle(tester);
    await tester.tap(find.text('Mercadona'));
    await settle(tester);

    expect(find.text('Visited /finanzas/movimientos'), findsOneWidget);
    final filters = container.read(transactionFiltersProvider);
    expect(filters.query, 'merca');
    expect(filters.periodScope, PeriodScope.all);
  });
}
