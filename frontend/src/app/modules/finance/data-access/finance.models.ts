import { IsoDate } from '@shared/dates/dates';

export type Cents = number;
export type BasisPoints = number;
export type ChartToken = 'c1' | 'c2' | 'c3' | 'c4' | 'c5' | 'c6' | 'c7' | 'c8';

export type AccountType = 'checking' | 'savings' | 'credit_card' | 'cash';
export type TransactionKind = 'expense' | 'income' | 'transfer' | 'adjustment';
export type TransactionStatus = 'pending' | 'cleared';
export type CategoryKind = 'expense' | 'income';
export type PeriodOpenedBy = 'payroll' | 'manual' | 'calendar';
export type PeriodMode = 'payroll' | 'calendar';
export type BudgetStatus = 'ok' | 'warning' | 'exceeded';
export type ShareMode = 'equal' | 'percentage' | 'amount';
export type RecurringMode = 'auto' | 'confirm';

export interface Paged<T> {
  data: T[];
}

export interface AccountRef {
  id: string;
  name: string;
  type: AccountType;
}

export interface CategorySummary {
  id: string;
  name: string;
  parent: string | null;
  parent_id: string | null;
  icon: string | null;
  color: string | null;
  kind: CategoryKind;
}

export interface Period {
  id: string;
  start_date: IsoDate;
  end_date: IsoDate | null;
  expected_end_date: IsoDate | null;
  effective_end_date: IsoDate;
  is_current: boolean;
  opened_by: PeriodOpenedBy;
  opening_transaction_id: string | null;
  name: string;
  short_name: string;
  range_label: string;
  label: string;
  days_total: number;
  days_elapsed: number;
  days_remaining: number;
}

export interface Account {
  id: string;
  name: string;
  type: AccountType;
  initial_balance_cents: Cents;
  initial_balance_date: IsoDate | null;
  balance_cents: Cents;
  cleared_balance_cents: Cents;
  pending_cents: Cents;
  credit_limit_cents: Cents | null;
  statement_day: number | null;
  payment_day: number | null;
  used_credit_cents: Cents | null;
  available_credit_cents: Cents | null;
  color: string | null;
  icon: string | null;
  include_in_net_worth: boolean;
  sort_order: number;
  archived: boolean;
  archived_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface AccountInput {
  name: string;
  type: AccountType;
  initial_balance_cents?: Cents;
  initial_balance_date?: IsoDate | null;
  credit_limit_cents?: Cents | null;
  statement_day?: number | null;
  payment_day?: number | null;
  color?: string | null;
  icon?: string | null;
  include_in_net_worth?: boolean;
  sort_order?: number;
  archived?: boolean;
}

export interface ReconcileResult {
  account: Account;
  adjustment: Transaction | null;
  difference_cents: Cents;
  balance_cents: Cents;
}

export interface Category {
  id: string;
  name: string;
  kind: CategoryKind;
  parent_id: string | null;
  icon: string | null;
  color: string | null;
  sort_order: number;
  opens_period: boolean;
  archived: boolean;
  children?: Category[];
}

export interface CategoryInput {
  name?: string;
  kind?: CategoryKind;
  parent_id?: string | null;
  icon?: string | null;
  color?: string | null;
  sort_order?: number;
  opens_period?: boolean;
  archived?: boolean;
}

export interface Tag {
  id: string;
  name: string;
  color: string | null;
  transactions_count: number;
}

export interface TransactionSplit {
  id: string;
  category_id: string;
  category: CategorySummary;
  amount_cents: Cents;
}

export interface TransactionShare {
  id: string;
  contact_id: string;
  name: string;
  amount_cents: Cents;
  settled: boolean;
  settled_at: string | null;
  settlement_transaction_id: string | null;
}

export interface Transaction {
  id: string;
  account_id: string;
  account: AccountRef;
  kind: TransactionKind;
  amount_cents: Cents;
  own_amount_cents: Cents;
  date: IsoDate;
  category_id: string | null;
  category: CategorySummary | null;
  payee: string | null;
  description: string | null;
  notes: string | null;
  tags: string[];
  status: TransactionStatus;
  transfer_group_id: string | null;
  transfer_account_id: string | null;
  recurring_rule_id: string | null;
  debt_id: string | null;
  splits: TransactionSplit[];
  shares: TransactionShare[];
  deleted: boolean;
  created_at: string | null;
  updated_at: string | null;
}

export interface SplitInput {
  category_id: string;
  amount_cents: Cents;
}

export interface ShareItemInput {
  contact_id: string;
  percentage?: number | null;
  amount_cents?: Cents | null;
}

export interface SharesInput {
  mode: ShareMode;
  include_self?: boolean;
  items: ShareItemInput[];
}

export interface TransactionInput {
  account_id?: string;
  kind?: Exclude<TransactionKind, 'transfer'>;
  amount_cents?: Cents;
  date?: IsoDate;
  category_id?: string | null;
  payee?: string | null;
  description?: string | null;
  notes?: string | null;
  status?: TransactionStatus;
  debt_id?: string | null;
  tags?: string[];
  splits?: SplitInput[] | null;
  shares?: SharesInput | null;
}

export interface TransferInput {
  from_account_id: string;
  to_account_id: string;
  amount_cents: Cents;
  date: IsoDate;
  description?: string | null;
  notes?: string | null;
  status?: TransactionStatus;
  tags?: string[];
}

export interface TransferResult {
  transfer_group_id: string;
  from: Transaction;
  to: Transaction;
}

export interface TransactionTotals {
  count: number;
  income_cents: Cents;
  expense_cents: Cents;
  own_expense_cents: Cents;
  net_cents: Cents;
}

export interface TransactionPage {
  data: Transaction[];
  meta: {
    per_page: number;
    has_more: boolean;
    next_cursor: string | null;
    totals: TransactionTotals;
  };
}

export interface MutationMeta {
  periods_changed: boolean;
}

export interface BulkUpdateInput {
  ids: string[];
  category_id?: string | null;
  account_id?: string;
  status?: TransactionStatus;
  tags?: string[];
  add_tags?: string[];
  remove_tags?: string[];
}

export interface PayeeSuggestion {
  payee: string;
  count: number;
  last_date: IsoDate;
  last_amount_cents: Cents;
  kind: CategoryKind;
  category: CategorySummary | null;
}

export interface BudgetCategory {
  id: string;
  name: string;
  parent: string | null;
  parent_id: string | null;
  icon: string | null;
  color: string | null;
  sort_key: number;
}

export interface BudgetRow {
  id: string;
  period_id: string;
  category_id: string;
  category: BudgetCategory;
  amount_cents: Cents;
  rollover: boolean;
  rollover_in_cents: Cents;
  available_cents: Cents;
  spent_cents: Cents;
  remaining_cents: Cents;
  percent_bp: BasisPoints | null;
  status: BudgetStatus;
  projected_cents: Cents;
  projected_status: BudgetStatus;
}

export interface BudgetTotals {
  budgeted_cents: Cents;
  spent_cents: Cents;
  remaining_cents: Cents;
  percent_bp: BasisPoints | null;
  projected_cents: Cents;
}

export interface BudgetOverview {
  data: BudgetRow[];
  meta: {
    period: Period;
    previous_period: Period | null;
    totals: BudgetTotals;
    copied?: number;
  };
}

export interface BudgetUpsertItem {
  category_id: string;
  amount_cents: Cents | null;
  rollover?: boolean;
}

export interface DashboardCategoryGroup {
  category_id: string | null;
  name: string;
  icon: string | null;
  color: string | null;
  amount_cents: Cents;
  percent_bp: BasisPoints;
  children: { category: CategorySummary; amount_cents: Cents }[];
}

export interface DashboardHistoryPoint {
  period_id: string;
  label: string;
  name: string;
  start_date: IsoDate;
  end_date: IsoDate | null;
  income_cents: Cents;
  expense_cents: Cents;
  net_worth_cents: Cents;
}

export interface UpcomingCharge {
  rule_id: string;
  name: string;
  date: IsoDate;
  amount_cents: Cents;
  account_id: string;
  category: CategorySummary | null;
  is_subscription: boolean;
  mode: RecurringMode;
}

export interface PeriodKpis {
  income_cents: Cents;
  expense_cents: Cents;
  savings_cents: Cents;
  savings_rate_bp: BasisPoints | null;
}

export interface Dashboard extends PeriodKpis {
  period: Period;
  previous_period: Period | null;
  net_worth_cents: Cents;
  net_worth_previous_cents: Cents | null;
  net_worth_delta_cents: Cents | null;
  previous: PeriodKpis | null;
  deltas_bp: { income: BasisPoints | null; expense: BasisPoints | null; savings: BasisPoints | null } | null;
  by_category: DashboardCategoryGroup[];
  history: DashboardHistoryPoint[];
  budgets: { top: BudgetRow[]; totals: BudgetTotals };
  upcoming: UpcomingCharge[];
  recent_transactions: Transaction[];
}

export interface FinanceSummary {
  period: Period;
  spent_cents: Cents;
  income_cents: Cents;
  savings_cents: Cents;
  remaining_days: number;
  net_worth_cents: Cents;
  budget: BudgetTotals;
  headline: string;
}

export interface FinanceSettings {
  default_account_id: string | null;
  last_used_account_id: string | null;
  budget_warning_threshold: number;
  period_min_days: number;
  period_mode: PeriodMode;
  remind_days_before: number;
}

export type FinanceSettingsInput = Partial<Omit<FinanceSettings, 'last_used_account_id'>>;

export interface ContactOption {
  id: string;
  name: string;
  archived: boolean;
  balance_cents: Cents;
}

export const ACCOUNT_TYPE_LABELS: Record<AccountType, string> = {
  checking: 'Corriente',
  savings: 'Ahorro',
  credit_card: 'Tarjeta de crédito',
  cash: 'Efectivo',
};

export const ACCOUNT_TYPE_ICONS: Record<AccountType, string> = {
  checking: 'landmark',
  savings: 'piggy-bank',
  credit_card: 'credit-card',
  cash: 'banknote',
};

export const KIND_LABELS: Record<TransactionKind, string> = {
  expense: 'Gasto',
  income: 'Ingreso',
  transfer: 'Transferencia',
  adjustment: 'Ajuste',
};
