import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/router/router.dart';
import 'package:carli/modules/finance/data/finance_providers.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/data/transaction_filters.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';
import '../../support/test_app.dart';

Future<ProviderContainer> pumpSignedIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(
    FakeApi({...financeBaseRoutes(), 'GET /v1/me': (_) => (200, {'data': testUser})}),
    storage: {'auth_token': 'stored'},
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
  await settle(tester);
  await tester.pump(const Duration(seconds: 2));
  await settle(tester);
  return container;
}

String locationOf(ProviderContainer container) =>
    container.read(routerProvider).routeInformationProvider.value.uri.toString();

void main() {
  group('TransactionFilters.fromQuery', () {
    test('reads the Angular query parameters', () {
      final filters = TransactionFilters.fromQuery({
        'periodo': ['todos'],
        'sin_categoria': ['1'],
        'cuenta': ['a-1,a-2'],
        'etiqueta': ['#Viaje'],
        'tipo': ['gasto', 'ingreso'],
        'estado': ['pendiente'],
        'min': ['1000'],
        'max': ['x'],
        'deuda': ['d-1'],
      });

      expect(filters.periodScope, PeriodScope.all);
      expect(filters.uncategorized, isTrue);
      expect(filters.accountIds, {'a-1', 'a-2'});
      expect(filters.tags, {'viaje'});
      expect(filters.kinds, {TransactionKind.expense, TransactionKind.income});
      expect(filters.status, TransactionStatus.pending);
      expect(filters.min, 1000);
      expect(filters.max, isNull);
      expect(filters.toApiQuery(null)['debt_id'], 'd-1');
    });

    test('searches every period when there is a text or a date range', () {
      expect(TransactionFilters.fromQuery({'q': ['luz']}).periodScope, PeriodScope.all);
      expect(TransactionFilters.fromQuery({'desde': ['2026-10-01']}).periodScope, PeriodScope.all);
      expect(TransactionFilters.fromQuery({'periodo': ['p-9']}).periodId, 'p-9');
      expect(TransactionFilters.fromQuery({'sin_categoria': ['1']}).periodScope, PeriodScope.current);
    });
  });

  testWidgets('applies the filters from a movements link and clears the query', (tester) async {
    final container = await pumpSignedIn(tester);

    container.read(routerProvider).go('${Routes.transactions}?sin_categoria=1&periodo=todos');
    await settle(tester);

    final filters = container.read(transactionFiltersProvider);
    expect(filters.uncategorized, isTrue);
    expect(filters.periodScope, PeriodScope.all);
    expect(locationOf(container), Routes.transactions);
  });

  testWidgets('opens the new income sheet from the payroll link', (tester) async {
    final container = await pumpSignedIn(tester);

    container.read(routerProvider).go('${Routes.newTransaction}?tipo=ingreso');
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Nuevo movimiento'), findsWidgets);
    expect(locationOf(container), Routes.transactions);
  });

  testWidgets('selects the period from a budgets link', (tester) async {
    final container = await pumpSignedIn(tester);

    container.read(routerProvider).go('${Routes.budgets}?periodo=p-sep');
    await settle(tester);

    expect(container.read(budgetsPeriodProvider), 'p-sep');
    expect(locationOf(container), Routes.budgets);
  });
}
