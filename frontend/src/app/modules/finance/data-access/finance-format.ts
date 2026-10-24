import { formatMoney, MINUS_SIGN } from '@shared/money/money';
import { formatShortDate } from '@shared/dates/dates';
import { BasisPoints, BudgetRow, BudgetStatus, Cents, ChartToken, Transaction } from './finance.models';

const percentFormatter = new Intl.NumberFormat('es-ES', { maximumFractionDigits: 1, minimumFractionDigits: 0 });
const integerPercentFormatter = new Intl.NumberFormat('es-ES', { maximumFractionDigits: 0 });

export function formatBasisPoints(value: BasisPoints | null | undefined, signed = false): string {
  if (value === null || value === undefined) {
    return '—';
  }
  const text = percentFormatter.format(Math.abs(value) / 100);
  const sign = value < 0 ? MINUS_SIGN : signed && value > 0 ? '+' : '';
  return `${sign}${text} %`;
}

export function formatPercentRounded(value: BasisPoints | null | undefined): string {
  if (value === null || value === undefined) {
    return '—';
  }
  return `${integerPercentFormatter.format(Math.round(value / 100))} %`;
}

export function basisPointsToRatio(value: BasisPoints | null | undefined): number {
  return value === null || value === undefined ? 0 : value / 10_000;
}

export const CHART_TOKENS: readonly ChartToken[] = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8'];

export function chartSlot(color: string | null | undefined): 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | null {
  const match = /^c([1-8])$/.exec(color ?? '');
  return match ? (Number(match[1]) as 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8) : null;
}

export type AmountTone = 'default' | 'positive' | 'muted';

export function transactionTone(transaction: Pick<Transaction, 'kind' | 'amount_cents'>): AmountTone {
  if (transaction.kind === 'transfer') {
    return 'muted';
  }
  return transaction.amount_cents > 0 ? 'positive' : 'default';
}

export function transactionAmountLabel(transaction: Pick<Transaction, 'kind' | 'amount_cents'>): string {
  return transaction.kind === 'transfer'
    ? formatMoney(transaction.amount_cents, 'absolute')
    : formatMoney(transaction.amount_cents, 'signed');
}

export function transactionTitle(transaction: Transaction): string {
  if (transaction.payee) {
    return transaction.payee;
  }
  if (transaction.description) {
    return transaction.description;
  }
  if (transaction.kind === 'transfer') {
    return transaction.amount_cents < 0 ? 'Transferencia enviada' : 'Transferencia recibida';
  }
  if (transaction.kind === 'adjustment') {
    return 'Ajuste de saldo';
  }
  if (transaction.splits.length > 0) {
    return 'Movimiento dividido';
  }
  return transaction.category?.name ?? 'Sin categoría';
}

export function budgetNote(status: BudgetStatus, remaining: Cents): string {
  return status === 'exceeded' || remaining < 0
    ? `Excedido en ${formatMoney(Math.abs(remaining))}`
    : `Te quedan ${formatMoney(remaining)}`;
}

export function budgetLimit(row: BudgetRow): Cents {
  return row.rollover_in_cents < 0 ? row.amount_cents : row.available_cents;
}

export function budgetConsumed(row: BudgetRow): Cents {
  return row.spent_cents - Math.min(row.rollover_in_cents, 0);
}

export function budgetUsageRatio(row: BudgetRow): number | null {
  const limit = budgetLimit(row);
  return limit > 0 ? budgetConsumed(row) / limit : null;
}

export function budgetUsageLabel(row: BudgetRow): string {
  const ratio = budgetUsageRatio(row);
  if (ratio === null) {
    return budgetConsumed(row) > 0 ? 'Excedido' : '0 %';
  }
  return formatPercentRounded(Math.round(ratio * 10_000));
}

export function inDaysLabel(days: number): string {
  if (days <= 0) {
    return 'hoy';
  }
  if (days === 1) {
    return 'mañana';
  }
  if (days === 2) {
    return 'pasado mañana';
  }
  return `en ${days} días`;
}

export function daysLeftLabel(days: number): string {
  if (days <= 0) {
    return 'último día';
  }
  return days === 1 ? 'queda 1 día' : `quedan ${days} días`;
}

export function shortDate(value: string): string {
  return formatShortDate(value);
}
