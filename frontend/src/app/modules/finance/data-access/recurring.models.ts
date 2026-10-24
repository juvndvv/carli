import { addDays, formatShortDate, IsoDate, parseIsoDate, WEEKDAYS_LONG, weekdayIndex } from '@shared/dates/dates';

export type FinanceAccountType = 'checking' | 'savings' | 'credit_card' | 'cash';
export type FinanceCategoryKind = 'expense' | 'income';

export interface FinanceAccountRef {
  id: string;
  name: string;
  type: FinanceAccountType;
}

export interface FinanceAccountLookup extends FinanceAccountRef {
  balance_cents: number;
  icon: string | null;
  archived: boolean;
}

export interface FinanceCategoryRef {
  id: string;
  name: string;
  parent: string | null;
  parent_id: string | null;
  icon: string | null;
  color: string | null;
  kind: FinanceCategoryKind;
}

export interface FinanceCategoryLookup {
  id: string;
  name: string;
  kind: FinanceCategoryKind;
  parent_id: string | null;
  icon: string | null;
  archived: boolean;
}

export type RecurrenceFrequency = 'daily' | 'weekly' | 'monthly' | 'yearly';
export type RecurringMode = 'auto' | 'confirm';
export type RecurringKind = 'expense' | 'income';

export interface RecurringPendingTransaction {
  id: string;
  date: IsoDate;
  amount_cents: number;
}

export interface RecurringRule {
  id: string;
  name: string;
  account_id: string;
  account: FinanceAccountRef;
  category_id: string | null;
  category: FinanceCategoryRef | null;
  kind: RecurringKind;
  amount_cents: number;
  payee: string | null;
  description: string | null;
  frequency: RecurrenceFrequency;
  interval: number;
  day_of_month: number | null;
  start_date: IsoDate;
  end_date: IsoDate | null;
  next_occurrence: IsoDate | null;
  mode: RecurringMode;
  remind_days_before: number;
  is_subscription: boolean;
  cancelled: boolean;
  cancelled_at: string | null;
  active: boolean;
  monthly_cost_cents: number;
  yearly_cost_cents: number;
  pending_transaction: RecurringPendingTransaction | null;
  debt_id: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface RecurringRulesMeta {
  active_count: number;
  monthly_total_cents: number;
  subscriptions: { count: number; monthly_cents: number; yearly_cents: number };
}

export interface RecurringRulePayload {
  account_id: string;
  kind: RecurringKind;
  amount_cents: number;
  frequency: RecurrenceFrequency;
  interval: number;
  start_date: IsoDate;
  end_date: IsoDate | null;
  category_id: string | null;
  payee: string | null;
  description?: string | null;
  day_of_month?: number | null;
  mode: RecurringMode;
  remind_days_before?: number;
  is_subscription: boolean;
}

export interface ConfirmRecurringPayload {
  amount_cents?: number | null;
  date?: IsoDate | null;
  update_rule_amount?: boolean;
}

export interface ConfirmRecurringResult {
  transaction: { id: string; amount_cents: number; date: IsoDate };
  rule: RecurringRule;
  price_changed: boolean;
  previous_amount_cents: number;
}

export interface FinanceReminderSettings {
  remind_days_before: number;
}

export type FrequencyPreset = 'weekly' | 'monthly' | 'quarterly' | 'yearly' | 'every_days' | 'every_months';

export const FREQUENCY_PRESETS: { value: FrequencyPreset; label: string }[] = [
  { value: 'weekly', label: 'Semanal' },
  { value: 'monthly', label: 'Mensual' },
  { value: 'quarterly', label: 'Trimestral' },
  { value: 'yearly', label: 'Anual' },
  { value: 'every_days', label: 'Cada N días' },
  { value: 'every_months', label: 'Cada N meses' },
];

export function presetToSchedule(preset: FrequencyPreset, customInterval: number): { frequency: RecurrenceFrequency; interval: number } {
  const interval = Math.max(1, Math.trunc(customInterval) || 1);
  switch (preset) {
    case 'weekly':
      return { frequency: 'weekly', interval: 1 };
    case 'monthly':
      return { frequency: 'monthly', interval: 1 };
    case 'quarterly':
      return { frequency: 'monthly', interval: 3 };
    case 'yearly':
      return { frequency: 'yearly', interval: 1 };
    case 'every_days':
      return { frequency: 'daily', interval };
    case 'every_months':
      return { frequency: 'monthly', interval };
  }
}

export function scheduleToPreset(frequency: RecurrenceFrequency, interval: number): FrequencyPreset {
  if (frequency === 'daily') {
    return 'every_days';
  }
  if (frequency === 'weekly') {
    return 'weekly';
  }
  if (frequency === 'yearly') {
    return 'yearly';
  }
  if (interval === 1) {
    return 'monthly';
  }
  return interval === 3 ? 'quarterly' : 'every_months';
}

type ScheduleLike = Pick<RecurringRule, 'frequency' | 'interval' | 'day_of_month' | 'start_date'>;

export function frequencyLabel(rule: ScheduleLike): string {
  const interval = Math.max(1, rule.interval);
  const start = parseIsoDate(rule.start_date);
  const day = rule.day_of_month ?? start?.day ?? null;
  switch (rule.frequency) {
    case 'daily':
      return interval === 1 ? 'Diario' : `Cada ${interval} días`;
    case 'weekly': {
      const weekday = WEEKDAYS_LONG[weekdayIndex(rule.start_date)];
      return interval === 1 ? `Semanal · ${weekday}` : `Cada ${interval} semanas · ${weekday}`;
    }
    case 'monthly': {
      const base = interval === 1 ? 'Mensual' : interval === 3 ? 'Trimestral' : interval === 6 ? 'Semestral' : `Cada ${interval} meses`;
      return day ? `${base} · día ${day}` : base;
    }
    case 'yearly': {
      const base = interval === 1 ? 'Anual' : `Cada ${interval} años`;
      return `${base} · ${formatShortDate(rule.start_date)}`;
    }
  }
}

export type RecurringTab = 'all' | 'subscriptions' | 'pending' | 'cancelled';

export function filterRecurringRules(rules: RecurringRule[], tab: RecurringTab): RecurringRule[] {
  switch (tab) {
    case 'all':
      return rules.filter((rule) => !rule.cancelled);
    case 'subscriptions':
      return rules.filter((rule) => rule.is_subscription && !rule.cancelled);
    case 'pending':
      return rules.filter((rule) => rule.pending_transaction !== null);
    case 'cancelled':
      return rules.filter((rule) => rule.cancelled);
  }
}

export function upcomingCharges(rules: RecurringRule[], today: IsoDate, days: number): RecurringRule[] {
  const limit = addDays(today, days);
  return rules
    .filter((rule) => rule.active && rule.next_occurrence !== null && rule.next_occurrence >= today && rule.next_occurrence <= limit)
    .sort((a, b) => (a.next_occurrence! < b.next_occurrence! ? -1 : a.next_occurrence! > b.next_occurrence! ? 1 : 0));
}

export function reminderLabel(days: number): string {
  if (days === 0) {
    return 'El mismo día';
  }
  return days === 1 ? '1 día antes' : `${days} días antes`;
}

export const ACCOUNT_TYPE_ICONS: Record<FinanceAccountType, string> = {
  checking: 'landmark',
  savings: 'piggy-bank',
  credit_card: 'credit-card',
  cash: 'banknote',
};

export interface FinanceOption {
  value: string;
  label: string;
  icon?: string | null;
  description?: string | null;
}

export function accountOptions(accounts: FinanceAccountLookup[]): FinanceOption[] {
  return accounts
    .filter((account) => !account.archived)
    .map((account) => ({ value: account.id, label: account.name, icon: account.icon || ACCOUNT_TYPE_ICONS[account.type] }));
}

export function categoryOptions(categories: FinanceCategoryLookup[], kind: FinanceCategoryKind): FinanceOption[] {
  const byId = new Map(categories.map((category) => [category.id, category]));
  return categories
    .filter((category) => category.kind === kind && !category.archived)
    .map((category) => {
      const parent = category.parent_id ? byId.get(category.parent_id) : undefined;
      return {
        value: category.id,
        label: parent ? `${parent.name} · ${category.name}` : category.name,
        icon: category.icon ?? parent?.icon ?? 'tag',
      };
    })
    .sort((a, b) => a.label.localeCompare(b.label, 'es'));
}

export function preferredAccountId(accounts: FinanceAccountLookup[], type: FinanceAccountType = 'checking'): string | null {
  const active = accounts.filter((account) => !account.archived);
  return (active.find((account) => account.type === type) ?? active[0])?.id ?? null;
}
