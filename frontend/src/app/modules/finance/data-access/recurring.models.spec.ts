import {
  accountOptions,
  categoryOptions,
  filterRecurringRules,
  frequencyLabel,
  presetToSchedule,
  RecurringRule,
  reminderLabel,
  scheduleToPreset,
  upcomingCharges,
} from './recurring.models';

function recurringRuleFixture(overrides: Partial<RecurringRule> = {}): RecurringRule {
  return {
    id: 'rule-1',
    name: 'Netflix',
    account_id: 'acc-1',
    account: { id: 'acc-1', name: 'Cuenta corriente', type: 'checking' },
    category_id: 'cat-1',
    category: { id: 'cat-1', name: 'Suscripciones', parent: null, parent_id: null, icon: 'repeat', color: 'c6', kind: 'expense' },
    kind: 'expense',
    amount_cents: -1399,
    payee: 'Netflix',
    description: null,
    frequency: 'monthly',
    interval: 1,
    day_of_month: 27,
    start_date: '2026-01-27',
    end_date: null,
    next_occurrence: '2026-10-27',
    mode: 'confirm',
    remind_days_before: 2,
    is_subscription: true,
    cancelled: false,
    cancelled_at: null,
    active: true,
    monthly_cost_cents: -1399,
    yearly_cost_cents: -16788,
    pending_transaction: null,
    debt_id: null,
    created_at: null,
    updated_at: null,
    ...overrides,
  };
}

describe('recurring models', () => {
  it('describes schedules in Spanish', () => {
    expect(frequencyLabel(recurringRuleFixture())).toBe('Mensual · día 27');
    expect(frequencyLabel(recurringRuleFixture({ interval: 3, day_of_month: 5 }))).toBe('Trimestral · día 5');
    expect(frequencyLabel(recurringRuleFixture({ frequency: 'yearly', start_date: '2026-03-03' }))).toBe('Anual · 3 mar');
    expect(frequencyLabel(recurringRuleFixture({ frequency: 'weekly', start_date: '2026-10-19' }))).toBe('Semanal · lunes');
    expect(frequencyLabel(recurringRuleFixture({ frequency: 'daily', interval: 10 }))).toBe('Cada 10 días');
    expect(frequencyLabel(recurringRuleFixture({ interval: 2, day_of_month: null, start_date: '2026-01-15' }))).toBe(
      'Cada 2 meses · día 15',
    );
  });

  it('maps frequency presets to API schedules and back', () => {
    expect(presetToSchedule('quarterly', 1)).toEqual({ frequency: 'monthly', interval: 3 });
    expect(presetToSchedule('every_days', 10)).toEqual({ frequency: 'daily', interval: 10 });
    expect(presetToSchedule('every_months', 0)).toEqual({ frequency: 'monthly', interval: 1 });
    expect(scheduleToPreset('monthly', 3)).toBe('quarterly');
    expect(scheduleToPreset('monthly', 1)).toBe('monthly');
    expect(scheduleToPreset('monthly', 4)).toBe('every_months');
    expect(scheduleToPreset('daily', 1)).toBe('every_days');
  });

  it('filters rules per tab', () => {
    const rules = [
      recurringRuleFixture({ id: 'sub' }),
      recurringRuleFixture({ id: 'rent', is_subscription: false }),
      recurringRuleFixture({ id: 'pending', pending_transaction: { id: 't', date: '2026-10-23', amount_cents: -1199 } }),
      recurringRuleFixture({ id: 'gone', cancelled: true, active: false }),
    ];
    expect(filterRecurringRules(rules, 'all').map((rule) => rule.id)).toEqual(['sub', 'rent', 'pending']);
    expect(filterRecurringRules(rules, 'subscriptions').map((rule) => rule.id)).toEqual(['sub', 'pending']);
    expect(filterRecurringRules(rules, 'pending').map((rule) => rule.id)).toEqual(['pending']);
    expect(filterRecurringRules(rules, 'cancelled').map((rule) => rule.id)).toEqual(['gone']);
  });

  it('lists upcoming charges sorted by date within the window', () => {
    const rules = [
      recurringRuleFixture({ id: 'late', next_occurrence: '2026-12-01' }),
      recurringRuleFixture({ id: 'second', next_occurrence: '2026-11-05' }),
      recurringRuleFixture({ id: 'first', next_occurrence: '2026-10-27' }),
      recurringRuleFixture({ id: 'inactive', next_occurrence: '2026-10-26', active: false }),
    ];
    expect(upcomingCharges(rules, '2026-10-24', 30).map((rule) => rule.id)).toEqual(['first', 'second']);
  });

  it('labels reminders', () => {
    expect(reminderLabel(2)).toBe('2 días antes');
    expect(reminderLabel(1)).toBe('1 día antes');
    expect(reminderLabel(0)).toBe('El mismo día');
  });

  it('builds account and category options', () => {
    const accounts = accountOptions([
      { id: 'a', name: 'Ahorro', type: 'savings', balance_cents: 0, icon: null, archived: false },
      { id: 'b', name: 'Vieja', type: 'checking', balance_cents: 0, icon: null, archived: true },
    ]);
    expect(accounts).toEqual([{ value: 'a', label: 'Ahorro', icon: 'piggy-bank' }]);

    const categories = categoryOptions(
      [
        { id: 'food', name: 'Alimentación', kind: 'expense', parent_id: null, icon: 'shopping-cart', archived: false },
        { id: 'super', name: 'Supermercado', kind: 'expense', parent_id: 'food', icon: null, archived: false },
        { id: 'pay', name: 'Nómina', kind: 'income', parent_id: null, icon: 'briefcase', archived: false },
      ],
      'expense',
    );
    expect(categories.map((option) => option.label)).toEqual(['Alimentación', 'Alimentación · Supermercado']);
    expect(categories[1].icon).toBe('shopping-cart');
  });
});
