import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/theme/tokens.dart';
import 'package:carli/modules/finance/screens/budgets_screen.dart';
import 'package:carli/modules/finance/screens/summary_screen.dart';
import 'package:carli/shell/home/home_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';

const nbsp = ' ';

void main() {
  testWidgets('shows budget states on the figure and the usage badge', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/budgets': (_) => (
        200,
        budgetsJson([
          budgetRowJson(),
          budgetRowJson(
            id: 'b-2',
            categoryId: 'cat-fun',
            name: 'Ocio',
            amount: 15000,
            spent: 14100,
            status: 'warning',
            sortKey: 2,
          ),
          budgetRowJson(
            id: 'b-3',
            categoryId: 'cat-cl',
            name: 'Ropa',
            amount: 15000,
            spent: 18250,
            status: 'exceeded',
            sortKey: 3,
          ),
        ]),
      ),
    });
    await pumpFinance(tester, const BudgetsScreen(), api);

    final warning = tester.widget<Text>(find.text('141,00$nbsp€ / 150,00$nbsp€'));
    expect(warning.style?.color, CarliColors.light.warning);
    final exceeded = tester.widget<Text>(find.text('182,50$nbsp€ / 150,00$nbsp€'));
    expect(exceeded.style?.color, CarliColors.light.negative);
    expect(find.text('94 %'), findsOneWidget);
    expect(find.text('Excedido en 32,50$nbsp€'), findsOneWidget);
    expect(find.text('Proyección fin de periodo'), findsOneWidget);
  });

  testWidgets('copies budgets from the previous period', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/budgets': (_) => (
        200,
        budgetsJson(
          const [],
          previous: periodJson(id: 'p-sep', current: false, shortName: 'sep'),
        ),
      ),
      'POST /v1/finance/budgets/copy': (_) => (
        200,
        {
          ...budgetsJson([budgetRowJson()]),
          'meta': {
            ...budgetsJson([budgetRowJson()])['meta'] as Map<String, dynamic>,
            'copied': 1,
          },
        },
      ),
    });
    await pumpFinance(tester, const BudgetsScreen(), api);

    expect(find.text('Aún no hay presupuestos en este periodo'), findsOneWidget);
    await tester.tap(find.text('Copiar de sep'));
    await settle(tester);

    expect((api.requests.singleWhere((r) => r.method == 'POST').data as Map)['from_period_id'], 'p-sep');
    expect(find.text('1 presupuesto copiado de sep'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('summarises the period', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/dashboard': (_) => (
        200,
        {
          'data': dashboardJson(recent: [transactionJson()]),
        },
      ),
    });
    await pumpFinance(tester, const SummaryScreen(), api);

    expect(find.text('18.345,00$nbsp€'), findsOneWidget);
    expect(find.text('Patrimonio'), findsWidgets);
    expect(find.text('−12 % vs sep'), findsOneWidget);
    expect(find.text('Tasa 54,2 %'), findsOneWidget);
    expect(find.text('OCTUBRE · QUEDA 1 DÍA'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Ritmo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mercadona'), 300);
    expect(find.text('Mercadona'), findsOneWidget);
  });

  testWidgets('asks for accounts before showing the summary', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(accounts: const []),
      'GET /v1/finance/dashboard': (_) => (200, {'data': dashboardJson()}),
    });
    await pumpFinance(tester, const SummaryScreen(), api);

    expect(find.text('Empieza por tus cuentas'), findsOneWidget);
  });

  testWidgets('greets on the home screen with the finance card', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/summary': (_) => (
        200,
        {
          'data': {
            'period': periodJson(),
            'spent_cents': 123456,
            'income_cents': 0,
            'savings_cents': 0,
            'remaining_days': 1,
            'net_worth_cents': 1834500,
            'budget': budgetTotals(budgeted: 100000, spent: 90000),
            'headline': '',
          },
        },
      ),
    });
    await pumpFinance(tester, HomeScreen(now: DateTime(2026, 10, 26, 9)), api);

    expect(find.text('Buenos días'), findsWidgets);
    expect(find.text('Lunes, 26 de octubre'), findsOneWidget);
    expect(find.text('18.345,00$nbsp€'), findsOneWidget);
    expect(find.text('90 % del presupuesto'), findsOneWidget);
  });

  testWidgets('edits limits and saves only the changes', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/budgets': (_) => (200, budgetsJson([budgetRowJson()])),
      'PUT /v1/finance/budgets': (_) => (200, budgetsJson([budgetRowJson()])),
    });
    await pumpFinance(tester, const BudgetsScreen(), api);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar presupuestos'), findsOneWidget);

    final casa = find.ancestor(of: find.text('Casa'), matching: find.byType(Row)).first;
    await tester.enterText(find.descendant(of: casa, matching: find.byType(TextField)), '250');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    final body = api.requests.singleWhere((r) => r.method == 'PUT').data as Map;
    expect(body['period_id'], 'p-oct');
    expect(body['budgets'], [
      {'category_id': 'cat-home', 'amount_cents': 25000, 'rollover': false},
    ]);
    expect(find.text('Presupuestos guardados'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('offers to create budgets when the period has none', (tester) async {
    final api = FakeApi({...financeBaseRoutes(), 'GET /v1/finance/budgets': (_) => (200, budgetsJson(const []))});
    await pumpFinance(tester, const BudgetsScreen(), api);

    expect(find.text('Crear presupuestos'), findsOneWidget);
    await tester.tap(find.text('Crear presupuestos'));
    await tester.pumpAndSettle();
    expect(find.text('Editar presupuestos'), findsOneWidget);
  });
}
