import { Account, Category, FinanceSettings, Period, Transaction } from '../data-access/finance.models';

export function aPeriod(overrides: Partial<Period> = {}): Period {
  return {
    id: 'period-current',
    start_date: '2026-09-28',
    end_date: null,
    expected_end_date: '2026-10-27',
    effective_end_date: '2026-10-27',
    is_current: true,
    opened_by: 'payroll',
    opening_transaction_id: null,
    name: 'Periodo de octubre',
    short_name: 'oct',
    range_label: '28 sep – 27 oct',
    label: 'Periodo de octubre (28 sep – 27 oct)',
    days_total: 30,
    days_elapsed: 27,
    days_remaining: 3,
    ...overrides,
  };
}

export function anAccount(overrides: Partial<Account> = {}): Account {
  return {
    id: 'account-checking',
    name: 'Cuenta corriente',
    type: 'checking',
    initial_balance_cents: 100000,
    initial_balance_date: '2026-09-01',
    balance_cents: 342865,
    cleared_balance_cents: 342865,
    pending_cents: 0,
    credit_limit_cents: null,
    statement_day: null,
    payment_day: null,
    used_credit_cents: null,
    available_credit_cents: null,
    color: 'c1',
    icon: 'landmark',
    include_in_net_worth: true,
    sort_order: 0,
    archived: false,
    archived_at: null,
    created_at: null,
    updated_at: null,
    ...overrides,
  };
}

export function aCategory(overrides: Partial<Category> = {}): Category {
  return {
    id: 'category-food',
    name: 'Alimentación',
    kind: 'expense',
    parent_id: null,
    icon: 'utensils',
    color: 'c2',
    sort_order: 0,
    opens_period: false,
    archived: false,
    children: [],
    ...overrides,
  };
}

export function aTransaction(overrides: Partial<Transaction> = {}): Transaction {
  return {
    id: 'tx-1',
    account_id: 'account-checking',
    account: { id: 'account-checking', name: 'Cuenta corriente', type: 'checking' },
    kind: 'expense',
    amount_cents: -4250,
    own_amount_cents: -4250,
    date: '2026-10-24',
    category_id: 'category-food',
    category: {
      id: 'category-food',
      name: 'Alimentación',
      parent: null,
      parent_id: null,
      icon: 'utensils',
      color: 'c2',
      kind: 'expense',
    },
    payee: 'Mercadona',
    description: null,
    notes: null,
    tags: [],
    status: 'cleared',
    transfer_group_id: null,
    transfer_account_id: null,
    recurring_rule_id: null,
    debt_id: null,
    splits: [],
    shares: [],
    deleted: false,
    created_at: null,
    updated_at: null,
    ...overrides,
  };
}

export function someSettings(overrides: Partial<FinanceSettings> = {}): FinanceSettings {
  return {
    default_account_id: null,
    last_used_account_id: null,
    budget_warning_threshold: 80,
    period_min_days: 20,
    period_mode: 'payroll',
    remind_days_before: 2,
    ...overrides,
  };
}

export const emptyTotals = { count: 0, income_cents: 0, expense_cents: 0, own_expense_cents: 0, net_cents: 0 };
