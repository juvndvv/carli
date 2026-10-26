import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/finance_format.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/screens/summary_screen.dart';

import '../../support/finance_fixtures.dart';

const nbsp = ' ';

BudgetRow row({int amount = 15000, int spent = 14100, int rolloverIn = 0, int? available, String status = 'warning'}) {
  final json = budgetRowJson(amount: amount, spent: spent, status: status)
    ..['rollover_in_cents'] = rolloverIn
    ..['available_cents'] = available ?? amount + rolloverIn;
  return BudgetRow.fromJson(json);
}

void main() {
  test('formats basis points as Spanish percentages', () {
    expect(formatBasisPoints(1234), '12,3 %');
    expect(formatBasisPoints(-1200, signed: true), '−12 %');
    expect(formatBasisPoints(900, signed: true), '+9 %');
    expect(formatBasisPoints(null), '—');
    expect(formatPercentRounded(9400), '94 %');
  });

  group('budgets', () {
    test('use the available amount as the limit, unless the rollover is an overspend', () {
      expect(budgetLimit(row(rolloverIn: 2000)), 17000);
      expect(budgetLimit(row(rolloverIn: -2000)), 15000);
      expect(budgetConsumed(row(rolloverIn: -2000)), 16100);
    });

    test('label the usage and the note', () {
      expect(budgetUsageLabel(row()), '94 %');
      expect(budgetUsageLabel(row(amount: 0, available: 0)), 'Excedido');
      expect(budgetNote(BudgetStatus.ok, 21000), 'Te quedan 210,00$nbsp€');
      expect(budgetNote(BudgetStatus.exceeded, -3250), 'Excedido en 32,50$nbsp€');
    });

    test('push the bar past full when there is spending without a limit', () {
      expect(budgetBarRatio(row(amount: 0, available: 0)), greaterThan(1));
      expect(budgetBarRatio(row(amount: 0, spent: 0, available: 0)), 0);
    });
  });

  group('transactions', () {
    Transaction transaction(Map<String, Object?> patch) => Transaction.fromJson({...transactionJson(), ...patch});

    test('title by payee, description, kind or category', () {
      expect(transactionTitle(transaction({})), 'Mercadona');
      expect(transactionTitle(transaction({'payee': null, 'description': 'Cena'})), 'Cena');
      expect(
        transactionTitle(transaction({'payee': null, 'kind': 'transfer', 'amount_cents': -500})),
        'Transferencia enviada',
      );
      expect(transactionTitle(transaction({'payee': null})), 'Comida');
      expect(transactionTitle(transaction({'payee': null, 'category_id': null, 'category': null})), 'Sin categoría');
    });

    test('sign amounts except transfers', () {
      expect(transactionAmountLabel(transaction({})), '−42,50$nbsp€');
      expect(transactionAmountLabel(transaction({'amount_cents': 269500, 'kind': 'income'})), '+2.695,00$nbsp€');
      expect(transactionAmountLabel(transaction({'amount_cents': -50000, 'kind': 'transfer'})), '500,00$nbsp€');
    });

    test('describe shared expenses', () {
      final shared = transaction({
        'shares': [
          {'name': 'Ana', 'amount_cents': 2000, 'settled': false},
        ],
      });
      expect(sharedSummary(shared), 'Ana te debe 20,00$nbsp€');
      expect(transactionSubtitle(shared), 'Comida · BBVA · Ana te debe 20,00$nbsp€');
    });
  });

  test('builds the donut with category slots, filling the gaps and grouping the tail', () {
    final groups = [
      for (var i = 0; i < 10; i++)
        DashboardCategoryGroup(name: 'C$i', color: i == 0 ? 'c3' : null, amountCents: 1000 - i * 10),
    ];
    final slices = buildDonut(groups);

    expect(slices, hasLength(8));
    expect(slices.first.slot, 3);
    expect(slices[1].slot, 1);
    expect(slices.last.label, 'Otros');
    expect(slices.last.slot, isNull);
    expect(slices.last.amount, 930 + 920 + 910);
  });

  test('describes uncategorized spending', () {
    final message = uncategorizedMessage(const UncategorizedSummary(expenseCents: 4250, count: 1));
    expect(message?.amount, '42,50$nbsp€ sin categorizar');
    expect(message?.detail, '1 gasto aún no cuenta en ningún presupuesto.');
    expect(uncategorizedMessage(const UncategorizedSummary(expenseCents: 0, count: 0)), isNull);
  });

  test('greets by time of day', () {
    expect(greetingFor(8), 'Buenos días');
    expect(greetingFor(15), 'Buenas tardes');
    expect(greetingFor(23), 'Buenas noches');
  });
}
