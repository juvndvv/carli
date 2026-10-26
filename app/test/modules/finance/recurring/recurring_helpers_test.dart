import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/finance_providers.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/data/recurring.dart';

import 'recurring_fixtures.dart';

const nbsp = '\u00a0';

void main() {
  test('describes schedules in Spanish', () {
    expect(ruleFrequencyLabel(recurringRule()), 'Mensual · día 27');
    expect(ruleFrequencyLabel(recurringRule(interval: 3, dayOfMonth: 5)), 'Trimestral · día 5');
    expect(ruleFrequencyLabel(recurringRule(frequency: 'yearly', startDate: '2026-03-03')), 'Anual · 3 mar');
    expect(ruleFrequencyLabel(recurringRule(frequency: 'weekly', startDate: '2026-10-19')), 'Semanal · lunes');
    expect(ruleFrequencyLabel(recurringRule(frequency: 'daily', interval: 10)), 'Cada 10 días');
    expect(
      ruleFrequencyLabel(recurringRule(interval: 2, dayOfMonth: null, startDate: '2026-01-15')),
      'Cada 2 meses · día 15',
    );
  });

  test('maps frequency presets to API schedules and back', () {
    expect(presetToSchedule(FrequencyPreset.quarterly, 1), (frequency: RecurrenceFrequency.monthly, interval: 3));
    expect(presetToSchedule(FrequencyPreset.everyDays, 10), (frequency: RecurrenceFrequency.daily, interval: 10));
    expect(presetToSchedule(FrequencyPreset.everyMonths, 0), (frequency: RecurrenceFrequency.monthly, interval: 1));
    expect(scheduleToPreset(RecurrenceFrequency.monthly, 3), FrequencyPreset.quarterly);
    expect(scheduleToPreset(RecurrenceFrequency.monthly, 1), FrequencyPreset.monthly);
    expect(scheduleToPreset(RecurrenceFrequency.monthly, 4), FrequencyPreset.everyMonths);
    expect(scheduleToPreset(RecurrenceFrequency.daily, 1), FrequencyPreset.everyDays);
  });

  test('filters rules per tab', () {
    final rules = [
      recurringRule(id: 'sub'),
      recurringRule(id: 'rent', isSubscription: false),
      recurringRule(id: 'pending', pending: {'id': 't', 'date': '2026-10-23', 'amount_cents': -1199}),
      recurringRule(id: 'gone', cancelled: true),
    ];
    List<String> ids(RecurringTab tab) => [for (final rule in filterRecurringRules(rules, tab)) rule.id];
    expect(ids(RecurringTab.all), ['sub', 'rent', 'pending']);
    expect(ids(RecurringTab.subscriptions), ['sub', 'pending']);
    expect(ids(RecurringTab.pending), ['pending']);
    expect(ids(RecurringTab.cancelled), ['gone']);
  });

  test('lists upcoming charges sorted by date within the window', () {
    final rules = [
      recurringRule(id: 'late', nextOccurrence: '2026-12-01'),
      recurringRule(id: 'second', nextOccurrence: '2026-11-05'),
      recurringRule(id: 'first', nextOccurrence: '2026-10-27'),
      recurringRule(id: 'inactive', nextOccurrence: '2026-10-26', active: false),
    ];
    expect([for (final rule in upcomingCharges(rules, DateTime(2026, 10, 24), 30)) rule.id], ['first', 'second']);
  });

  test('labels reminders', () {
    expect(reminderLabel(2), '2 días antes');
    expect(reminderLabel(1), '1 día antes');
    expect(reminderLabel(0), 'El mismo día');
  });

  test('builds account and category options', () {
    const accounts = [
      Account(id: 'a', name: 'Ahorro', type: AccountType.savings, balanceCents: 0, icon: null, archived: false),
      Account(id: 'b', name: 'Vieja', type: AccountType.checking, balanceCents: 0, icon: null, archived: true),
    ];
    final accountOptions = recurringAccountOptions(accounts);
    expect(
      [for (final option in accountOptions) (option.id, option.label, option.icon)],
      [('a', 'Ahorro', 'piggy-bank')],
    );
    expect(preferredAccountId(accounts), 'a');

    final categories = CategoryIndex(const [
      Category(
        id: 'food',
        name: 'Alimentación',
        kind: CategoryKind.expense,
        icon: 'shopping-cart',
        archived: false,
        children: [
          Category(id: 'super', name: 'Supermercado', kind: CategoryKind.expense, icon: null, archived: false),
        ],
      ),
      Category(id: 'pay', name: 'Nómina', kind: CategoryKind.income, icon: 'briefcase', archived: false),
    ]);
    final options = recurringCategoryOptions(categories, CategoryKind.expense);
    expect([for (final option in options) option.label], ['Alimentación', 'Alimentación · Supermercado']);
    expect(options[1].icon, 'shopping-cart');
  });

  test('prefers a checking account and skips archived ones', () {
    const accounts = [
      Account(id: 'cash', name: 'Efectivo', type: AccountType.cash, balanceCents: 0, icon: null, archived: false),
      Account(id: 'old', name: 'Vieja', type: AccountType.checking, balanceCents: 0, icon: null, archived: true),
      Account(id: 'main', name: 'BBVA', type: AccountType.checking, balanceCents: 0, icon: null, archived: false),
    ];
    expect(preferredAccountId(accounts), 'main');
    expect(preferredAccountId(const []), isNull);
  });

  test('describes each rule row like the web list', () {
    expect(recurringSubtitle(recurringRule()), 'Mensual · día 27 · próximo 27 oct');
    expect(
      recurringSubtitle(recurringRule(pending: {'id': 't', 'date': '2026-10-23', 'amount_cents': -1199})),
      'Mensual · día 27 · pendiente del 23 oct',
    );
    expect(recurringSubtitle(recurringRule(nextOccurrence: null)), 'Mensual · día 27 · finalizado');
    expect(recurringSubtitle(recurringRule(cancelled: true)), 'Mensual · día 27');
    expect(recurringIconName(recurringRule()), 'repeat');
  });

  test('labels upcoming charges relative to today', () {
    final now = DateTime(2026, 10, 24);
    expect(upcomingChargeLabel(recurringRule(nextOccurrence: '2026-10-25'), now: now), 'Mañana · Cuenta corriente');
    expect(
      upcomingChargeLabel(recurringRule(nextOccurrence: '2026-10-27'), now: now),
      'Martes 27 oct · en 3 días · Cuenta corriente',
    );
  });

  test('adds months clamping to the last day', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 10, 26), 12), DateTime(2027, 10, 26));
  });

  test('builds the rule payload from a draft', () {
    final draft = RecurringDraft.from(null, isSubscription: true, now: DateTime(2026, 10, 26))
      ..amount = 1399
      ..payee = '  Netflix '
      ..accountId = 'acc-main'
      ..preset = FrequencyPreset.everyMonths
      ..interval = 2;
    expect(draft.valid, isTrue);
    expect(draft.toPayload(), {
      'kind': 'expense',
      'amount_cents': -1399,
      'payee': 'Netflix',
      'account_id': 'acc-main',
      'category_id': null,
      'frequency': 'monthly',
      'interval': 2,
      'start_date': '2026-10-26',
      'end_date': null,
      'mode': 'auto',
      'remind_days_before': 2,
      'is_subscription': true,
    });

    draft.setHasEnd(true);
    expect(draft.endDate, DateTime(2027, 10, 26));
    draft.endDate = DateTime(2026, 1, 1);
    expect(draft.endBeforeStart, isTrue);
    expect(draft.valid, isFalse);
  });

  test('validates required draft fields', () {
    final draft = RecurringDraft.from(null);
    expect(draft.amountInvalid, isTrue);
    expect(draft.payeeInvalid, isTrue);
    expect(draft.accountInvalid, isTrue);
    draft
      ..preset = FrequencyPreset.everyDays
      ..interval = 400;
    expect(draft.intervalInvalid, isTrue);
    draft.remindDaysBefore = 31;
    expect(draft.remindInvalid, isTrue);
  });

  test('prefills a draft from an existing rule', () {
    final draft = RecurringDraft.from(recurringRule(interval: 3, kind: 'income', amount: 265000));
    expect(draft.kind, TransactionKind.income);
    expect(draft.amount, 265000);
    expect(draft.preset, FrequencyPreset.quarterly);
    expect(draft.interval, 3);
    expect(draft.mode, RecurringMode.confirm);
    expect(draft.toPayload()['amount_cents'], 265000);
  });

  test('detects price changes against the absolute expected amount', () {
    expect(detectPriceChange(-1399, 1399), isNull);
    expect(detectPriceChange(-1399, null), isNull);
    expect(
      detectPriceChange(-1399, 1499),
      const PriceChange(direction: PriceDirection.up, differenceCents: 100, percent: 7),
    );
    expect(
      detectPriceChange(-1399, 1199),
      const PriceChange(direction: PriceDirection.down, differenceCents: 200, percent: 14),
    );
    expect(detectPriceChange(-1399, 1499)!.title, 'Sube 1,00$nbsp€ (7 %) respecto a lo previsto');
  });

  test('builds the confirm payload only updating the rule when the price changed', () {
    final rule = recurringRule();
    expect(confirmOccurrencePayload(rule: rule, amount: 1499, date: DateTime(2026, 10, 27), updateRuleAmount: true), {
      'amount_cents': 1499,
      'date': '2026-10-27',
      'update_rule_amount': true,
    });
    expect(
      confirmOccurrencePayload(
        rule: rule,
        amount: 1399,
        date: DateTime(2026, 10, 27),
        updateRuleAmount: true,
      )['update_rule_amount'],
      isFalse,
    );
  });
}
