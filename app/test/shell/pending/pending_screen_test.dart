import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/pending/pending_models.dart';
import 'package:carli/core/pending/pending_providers.dart';
import 'package:carli/core/pending/pending_types.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/data/transaction_filters.dart';
import 'package:carli/shell/pending/pending_actions.dart';
import 'package:carli/shell/pending/pending_screen.dart';
import 'package:carli/ui/chip.dart';

import '../../core/pending/pending_fixtures.dart';
import '../../modules/finance/recurring/recurring_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';
import 'pending_app.dart';

const _listRoute = 'GET /v1/pending';
const _summaryRoute = 'GET /v1/pending/summary';

class _ResolveAction extends ConsumerWidget {
  const _ResolveAction({required this.item, required this.onResolved});

  final PendingItem item;
  final ValueChanged<PendingItem> onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TextButton(onPressed: () => onResolved(item), child: Text('Resolver ${item.title}'));
}

final _resolveRegistry = pendingActionRegistryProvider.overrideWithValue(
  PendingActionRegistry({
    FinancePendingTypes.module: PendingModuleActions(
      actions: {
        FinancePendingTypes.uncategorized: (item, onResolved) => _ResolveAction(item: item, onResolved: onResolved),
      },
      open: openFinancePendingRoute,
    ),
  }),
);

class _PendingBackend {
  _PendingBackend(this.items, {this.cursor});

  List<Json> items;
  String? cursor;

  Map<String, FakeRoute> routes({Json? summary}) => {
    _listRoute: (options) => (
      200,
      pendingPageJson(
        options.queryParameters['cursor'] == null ? _filtered(options) : [],
        cursor: options.queryParameters['cursor'] == null ? cursor : null,
      ),
    ),
    _summaryRoute: (_) => (200, summary ?? _summary()),
  };

  List<Json> _filtered(RequestOptions options) {
    final type = options.queryParameters['type'] as String?;
    return [
      for (final item in items)
        if (type == null || item['type'] == type) item,
    ];
  }

  Json _summary() => pendingSummaryJson(
    uncategorized: items.where((item) => item['type'] == 'uncategorized_transaction').length,
    recurring: items.where((item) => item['type'] == 'recurring_to_confirm').length,
  );

  void remove(String id) => items = [
    for (final item in items)
      if (item['id'] != id) item,
  ];
}

List<String> _chipLabels(WidgetTester tester) => [
  for (final chip in tester.widgetList<CarliChip>(find.byType(CarliChip))) chip.label!,
];

void main() {
  test('groups items by module and type with the summary counts', () {
    final items = [
      PendingItem.fromJson(pendingItemJson()),
      PendingItem.fromJson(pendingItemJson(id: 'tx-2')),
      PendingItem.fromJson(recurringPendingJson()),
      PendingItem.fromJson(pendingItemJson(module: 'tasks', type: 'overdue_task', id: 't-1')),
    ];
    final summary = PendingSummary.fromJson(pendingSummaryJson(uncategorized: 5)['data'] as PendingJson);
    final groups = groupPendingItems(
      items,
      summary.entries,
      PendingTypeRegistry({FinancePendingTypes.module: financePendingModule}),
    );

    expect(groups.map((group) => (group.module, group.name, group.icon)), [
      ('finance', 'Finanzas', 'wallet'),
      ('tasks', 'tasks', 'inbox'),
    ]);
    expect(groups.first.types.map((group) => (group.type, group.count, group.items.length)), [
      ('uncategorized_transaction', 5, 2),
      ('recurring_to_confirm', 1, 1),
    ]);
    expect(groups.last.types.single.descriptor.label, 'Overdue task');
    expect(groups.last.types.single.count, 1);
  });

  testWidgets('lists items grouped by type with their native actions', (tester) async {
    final backend = _PendingBackend([
      pendingItemJson(),
      pendingItemJson(id: 'tx-2', title: 'Lidl'),
      recurringPendingJson(),
    ]);
    await pumpPendingRouter(tester, FakeApi({...financeBaseRoutes(), ...backend.routes()}));

    expect(find.text('Pendientes'), findsWidgets);
    expect(find.text('3 elementos por revisar'), findsOneWidget);
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('Movimientos por categorizar'), findsOneWidget);
    expect(find.text('Recurrentes por confirmar'), findsOneWidget);
    expect(find.text('Mercadona'), findsOneWidget);
    expect(find.textContaining('BBVA · Importado del banco'), findsNWidgets(2));
    expect(find.text('−42,50 €'), findsNWidgets(2));
    expect(find.text('Elegir categoría'), findsNWidgets(2));
    expect(find.text('Confirmar cargo'), findsOneWidget);
    expect(find.text('Ver todos'), findsNWidgets(2));
    expect(_chipLabels(tester), ['Todo (3)', 'Movimientos por categorizar (2)', 'Recurrentes por confirmar (1)']);
  });

  testWidgets('drops an item and decrements the counts once its action resolves it', (tester) async {
    final backend = _PendingBackend([
      pendingItemJson(),
      pendingItemJson(id: 'tx-2', title: 'Lidl'),
      recurringPendingJson(),
    ]);
    final app = await pumpPendingRouter(tester, FakeApi(backend.routes()), overrides: [_resolveRegistry]);

    expect(find.text('Revisar'), findsOneWidget);
    await tester.tap(find.text('Resolver Mercadona'));
    await tester.pump();

    expect(find.text('Mercadona'), findsNothing);
    expect(find.text('Lidl'), findsOneWidget);
    expect(app.container.read(pendingSummaryProvider).value!.count('finance', 'uncategorized_transaction'), 1);
    expect(_chipLabels(tester), ['Todo (2)', 'Movimientos por categorizar (1)', 'Recurrentes por confirmar (1)']);
    await settle(tester);
  });

  testWidgets('filters by module and type from the query and switches with the chips', (tester) async {
    final backend = _PendingBackend([
      pendingItemJson(),
      pendingItemJson(id: 'tx-2', title: 'Lidl'),
      recurringPendingJson(),
    ]);
    final api = FakeApi(backend.routes());
    final app = await pumpPendingRouter(tester, api, location: '/pendientes?modulo=finance&tipo=recurring_to_confirm');

    final first = api.requests.firstWhere((request) => request.path == '/v1/pending');
    expect(first.queryParameters, {'module': 'finance', 'type': 'recurring_to_confirm'});
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Mercadona'), findsNothing);
    expect(find.text('Finanzas'), findsNothing);
    final chips = tester.widgetList<CarliChip>(find.byType(CarliChip)).toList();
    expect(chips.map((chip) => chip.selected), [false, false, true]);

    await tapAndSettle(tester, find.text('Todo (3)'));

    expect(app.router.routerDelegate.currentConfiguration.uri.toString(), '/pendientes');
    expect(api.requests.last.queryParameters, isEmpty);
    expect(find.text('Mercadona'), findsOneWidget);
    expect(find.text('Finanzas'), findsOneWidget);

    await tapAndSettle(tester, find.text('Movimientos por categorizar (2)'));
    expect(
      app.router.routerDelegate.currentConfiguration.uri.toString(),
      '/pendientes?modulo=finance&tipo=uncategorized_transaction',
    );
    expect(find.text('Netflix'), findsNothing);
  });

  testWidgets('loads the next page with the cursor', (tester) async {
    final backend = _PendingBackend([pendingItemJson()], cursor: 'next');
    final routes = backend.routes();
    final api = FakeApi({
      ...routes,
      _listRoute: (options) => options.queryParameters['cursor'] == 'next'
          ? (200, pendingPageJson([pendingItemJson(id: 'tx-3', title: 'Repsol')]))
          : routes[_listRoute]!(options),
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Cargar más'));

    expect(api.requests.last.queryParameters, {'cursor': 'next'});
    expect(find.text('Repsol'), findsOneWidget);
    expect(find.text('Cargar más'), findsNothing);
  });

  testWidgets('shows an empty state when there is nothing to review', (tester) async {
    await pumpPendingRouter(tester, FakeApi(_PendingBackend([]).routes()));

    expect(find.text('Todo al día'), findsOneWidget);
    expect(find.text('Nada por revisar'), findsOneWidget);
    expect(find.byType(CarliChip), findsNothing);
  });

  testWidgets('offers every pending item when a filtered type is empty', (tester) async {
    final app = await pumpPendingRouter(
      tester,
      FakeApi(_PendingBackend([pendingItemJson()]).routes()),
      location: '/pendientes?modulo=finance&tipo=recurring_to_confirm',
    );

    expect(find.text('Nada pendiente de este tipo'), findsOneWidget);
    await tapAndSettle(tester, find.text('Ver todos los pendientes'));
    expect(app.router.routerDelegate.currentConfiguration.uri.toString(), '/pendientes');
    expect(find.text('Mercadona'), findsOneWidget);
  });

  testWidgets('offers a retry when the list fails to load', (tester) async {
    var fail = true;
    final backend = _PendingBackend([pendingItemJson()]);
    final routes = backend.routes();
    await pumpPendingRouter(
      tester,
      FakeApi({
        ...routes,
        _listRoute: (options) => fail ? (500, {'message': 'boom'}) : routes[_listRoute]!(options),
      }),
    );

    expect(find.text('No se han podido cargar los pendientes'), findsOneWidget);
    expect(find.text('Comprueba tu conexión e inténtalo de nuevo.'), findsOneWidget);
    fail = false;
    await tapAndSettle(tester, find.text('Reintentar'));
    expect(find.text('Mercadona'), findsOneWidget);
  });

  testWidgets('opens the native recurring screen from a group', (tester) async {
    final app = await pumpPendingRouter(tester, FakeApi(_PendingBackend([recurringPendingJson()]).routes()));

    await tapAndSettle(tester, find.text('Ver todos'));
    expect(app.router.routerDelegate.currentConfiguration.uri.toString(), '/mas/recurrentes');
    expect(find.text('Pantalla de recurrentes'), findsOneWidget);
  });

  testWidgets('opens uncategorized transactions across every period', (tester) async {
    final app = await pumpPendingRouter(tester, FakeApi(_PendingBackend([pendingItemJson()]).routes()));

    await tapAndSettle(tester, find.text('Ver todos'));
    expect(find.text('Pantalla de movimientos'), findsOneWidget);
    final filters = app.container.read(transactionFiltersProvider);
    expect(filters.uncategorized, isTrue);
    expect(filters.periodScope, PeriodScope.all);
  });

  testWidgets('categorizes a transaction, resolves it and offers similar ones', (tester) async {
    final backend = _PendingBackend([pendingItemJson(), recurringPendingJson()]);
    final api = FakeApi({
      ...financeBaseRoutes(),
      ...backend.routes(),
      'PATCH /v1/finance/transactions/tx-1': (_) {
        backend.remove('tx-1');
        return (200, {'data': transactionJson(categoryId: 'cat-home', categoryName: 'Casa'), 'meta': {}});
      },
      'GET /v1/finance/transactions/tx-1/similar': (_) => (
        200,
        {
          'data': {'count': 2},
        },
      ),
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Elegir categoría'));
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Nómina'), findsNothing);
    await tapAndSettle(tester, find.text('Casa'));

    final patch = api.requests.singleWhere((request) => request.method == 'PATCH');
    expect(patch.data, {'category_id': 'cat-home'});
    expect(find.text('Mercadona'), findsNothing);
    expect(find.text('Mercadona → Casa'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
    expect(api.requests.where((request) => request.path == '/v1/finance/transactions/tx-1/similar'), hasLength(1));
    expect(_chipLabels(tester), isEmpty);
    expect(find.text('1 elemento por revisar'), findsOneWidget);
    await drainToasts(tester);
  });

  testWidgets('keeps the item when saving the category fails', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      ..._PendingBackend([pendingItemJson()]).routes(),
      'PATCH /v1/finance/transactions/tx-1': (_) => (
        422,
        {
          'message': 'Categoría no válida.',
          'errors': {
            'category_id': ['Categoría no válida.'],
          },
        },
      ),
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Elegir categoría'));
    await tapAndSettle(tester, find.text('Casa'));

    expect(find.text('Categoría no válida.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Cancelar'));
    expect(find.text('Mercadona'), findsOneWidget);
    expect(api.requests.where((request) => request.path.endsWith('/similar')), isEmpty);
    await drainToasts(tester);
  });

  testWidgets('confirms a recurring charge and resolves the item', (tester) async {
    final backend = _PendingBackend([recurringPendingJson()]);
    final api = FakeApi({
      ...financeBaseRoutes(),
      ...backend.routes(),
      'GET /v1/finance/recurring-rules/netflix': (_) => (
        200,
        {
          'data': recurringRuleJson(pending: {'id': 'tx-r', 'date': '2026-10-23', 'amount_cents': -1399}),
        },
      ),
      'POST /v1/finance/recurring-rules/netflix/confirm': (_) {
        backend.remove('tx-r');
        return (
          200,
          {
            'data': {
              'transaction': {'id': 'tx-r', 'amount_cents': -1399, 'date': '2026-10-23'},
              'rule': recurringRuleJson(nextOccurrence: '2026-11-27'),
              'price_changed': false,
              'previous_amount_cents': -1399,
            },
          },
        );
      },
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Confirmar cargo'));
    expect(find.text('Confirmar Netflix'), findsOneWidget);
    await tapAndSettle(tester, find.text('Confirmar cargo').last);

    expect(api.requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(find.text('Netflix'), findsNothing);
    expect(find.text('Todo al día'), findsOneWidget);
    await drainToasts(tester);
  });

  testWidgets('leaves the recurring item when the confirm sheet is dismissed', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      ..._PendingBackend([recurringPendingJson()]).routes(),
      'GET /v1/finance/recurring-rules/netflix': (_) => (200, {'data': recurringRuleJson()}),
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Confirmar cargo'));
    expect(find.text('Confirmar Netflix'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await settle(tester);

    expect(find.text('Confirmar Netflix'), findsNothing);
    expect(find.text('Netflix'), findsOneWidget);
  });
}
