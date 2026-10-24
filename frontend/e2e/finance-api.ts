import { FinanceApi } from './support';

export interface AccountDto {
  id: string;
  name: string;
  type: string;
  balance_cents: number;
  cleared_balance_cents: number;
  archived: boolean;
}

export interface TransactionDto {
  id: string;
  kind: string;
  amount_cents: number;
  date: string;
  status: 'pending' | 'cleared';
  category_id: string | null;
  account_id: string;
  payee: string | null;
  shares: { contact_id: string; amount_cents: number; settled: boolean }[];
}

export interface BudgetRowDto {
  category_id: string;
  category: { name: string };
  amount_cents: number;
}

export interface BudgetOverviewDto {
  data: BudgetRowDto[];
  meta: { period: { id: string }; previous_period: { id: string; short_name: string } | null };
}

export interface RecurringRuleDto {
  id: string;
  name: string;
  next_occurrence: string | null;
  remind_days_before: number;
  cancelled: boolean;
  is_subscription: boolean;
}

export interface ContactDto {
  id: string;
  name: string;
  balance_cents: number;
}

export async function primaryAccount(api: FinanceApi): Promise<AccountDto> {
  const { data } = await api.get<{ data: AccountDto[] }>('finance/accounts');
  const account = data.find((item) => item.type === 'checking' && !item.archived) ?? data[0];
  if (!account) {
    throw new Error('The demo user has no accounts; run make seed-demo first.');
  }
  return account;
}

export async function deleteTransaction(api: FinanceApi, id: string): Promise<void> {
  await api.send('DELETE', `finance/transactions/${id}`);
}

export async function findTransactionByPayee(api: FinanceApi, payee: string): Promise<TransactionDto | undefined> {
  const { data } = await api.get<{ data: TransactionDto[] }>(
    `finance/transactions?q=${encodeURIComponent(payee)}&per_page=5`,
  );
  return data.find((item) => item.payee === payee);
}

export function shiftIsoDate(iso: string, days: number): string {
  const date = new Date(`${iso}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function centsToInput(cents: number): string {
  const sign = cents < 0 ? '-' : '';
  const absolute = Math.abs(cents);
  return `${sign}${Math.trunc(absolute / 100)},${String(absolute % 100).padStart(2, '0')}`;
}
