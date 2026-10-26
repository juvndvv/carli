import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/accounts_admin.dart';
import 'package:carli/modules/finance/data/models.dart';

import '../../../support/finance_fixtures.dart';
import 'accounts_fixtures.dart';

const nbsp = '\u00a0';

void main() {
  test('walks back from the current balance day by day', () {
    final points = balanceHistory(
      10000,
      [
        Transaction.fromJson(transactionJson(date: DateTime(2026, 10, 24), amount: -2000)),
        Transaction.fromJson(transactionJson(id: 'b', date: DateTime(2026, 10, 22), amount: 5000)),
        Transaction.fromJson(transactionJson(id: 'c', date: DateTime(2026, 10, 26), amount: -1000)),
      ],
      DateTime(2026, 10, 24),
      4,
    );

    expect(
      [for (final point in points) (point.date, point.balanceCents)],
      [
        (DateTime(2026, 10, 21), 8000),
        (DateTime(2026, 10, 22), 13000),
        (DateTime(2026, 10, 23), 13000),
        (DateTime(2026, 10, 24), 11000),
      ],
    );
  });

  test('starts reconciling from the bank balance on linked accounts', () {
    expect(reconcileStartingBalance(AccountDetails.fromJson(fullAccountJson())), 342865);
    expect(reconcileStartingBalance(AccountDetails.fromJson(fullAccountJson(bank: bankLinkJson()))), 343365);
    expect(
      reconcileStartingBalance(AccountDetails.fromJson(fullAccountJson(bank: bankLinkJson(balance: null)))),
      342865,
    );
  });

  test('describes card schedules and account summaries', () {
    final card = AccountDetails.fromJson(
      fullAccountJson(type: 'credit_card', balance: -12000, creditLimit: 300000, statementDay: 5, paymentDay: 10),
    );
    expect(cardSchedule(card), 'Corte día 5 · se carga el día 10');
    expect(cardSchedule(AccountDetails.fromJson(fullAccountJson())), isNull);
    expect(accountsSummaryLabel([card]), '1 cuenta · las tarjetas de crédito restan');
    expect(accountsSummaryLabel([AccountDetails.fromJson(fullAccountJson()), card]).startsWith('2 cuentas'), isTrue);
    expect(archivedAccountsLabel(1), '1 cuenta archivada');
    expect(archivedAccountsLabel(3), '3 cuentas archivadas');
  });

  test('summarises the linked bank balance', () {
    final now = DateTime(2026, 10, 26, 12);
    final off = bankBalanceSummary(
      BankLinkDetails.fromJson(bankLinkJson(balanceAt: DateTime(2026, 10, 26, 9, 5).toIso8601String())),
      now: now,
    )!;
    expect(off.balance, '3.433,65$nbsp€');
    expect(off.difference, '+5,00$nbsp€');
    expect(off.matches, isFalse);
    expect(off.updated, 'hoy a las 09:05');

    final matching = bankBalanceSummary(BankLinkDetails.fromJson(bankLinkJson(difference: 0)))!;
    expect(matching.matches, isTrue);
    expect(matching.difference, isNull);
    expect(formatDateTime(DateTime(2026, 10, 25, 18, 30), now: now), 'ayer a las 18:30');
    expect(formatDateTime(DateTime(2026, 9, 2, 8), now: now), '2 sep, 08:00');
  });

  test('drops credit card fields for other account types', () {
    final input = AccountInput(
      name: '  Ahorro  ',
      type: AccountType.savings,
      initialBalanceCents: 5000,
      initialBalanceDate: DateTime(2026, 10, 1),
      creditLimitCents: 100000,
      statementDay: 3,
      paymentDay: 4,
      icon: 'piggy-bank',
      color: 'c3',
      includeInNetWorth: false,
    );

    expect(input.toJson(), {
      'name': 'Ahorro',
      'type': 'savings',
      'initial_balance_cents': 5000,
      'initial_balance_date': '2026-10-01',
      'credit_limit_cents': null,
      'statement_day': null,
      'payment_day': null,
      'icon': 'piggy-bank',
      'color': 'c3',
      'include_in_net_worth': false,
    });
  });
}
