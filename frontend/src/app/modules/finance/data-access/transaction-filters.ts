import { Params } from '@angular/router';
import { IsoDate } from '@shared/dates/dates';
import { QueryValue } from './finance-api';
import { Cents, TransactionKind, TransactionStatus } from './finance.models';

export type PeriodSelection = 'current' | 'all' | string;

export interface TransactionFilters {
  period: PeriodSelection;
  from: IsoDate | null;
  to: IsoDate | null;
  accountIds: string[];
  categoryIds: string[];
  tags: string[];
  kinds: TransactionKind[];
  min: Cents | null;
  max: Cents | null;
  q: string;
  status: TransactionStatus | null;
  debtId: string | null;
  recurringRuleId: string | null;
  contactId: string | null;
}

export const UNCATEGORIZED = 'none';

export const EMPTY_FILTERS: TransactionFilters = {
  period: 'current',
  from: null,
  to: null,
  accountIds: [],
  categoryIds: [],
  tags: [],
  kinds: [],
  min: null,
  max: null,
  q: '',
  status: null,
  debtId: null,
  recurringRuleId: null,
  contactId: null,
};

const QUERY_KEYS = {
  period: 'periodo',
  from: 'desde',
  to: 'hasta',
  accountIds: 'cuenta',
  categoryIds: 'categoria',
  tags: 'etiqueta',
  kinds: 'tipo',
  min: 'min',
  max: 'max',
  q: 'q',
  status: 'estado',
  debtId: 'deuda',
  recurringRuleId: 'recurrente',
  contactId: 'contacto',
} as const satisfies Record<keyof TransactionFilters, string>;

const KIND_PARAMS: Record<string, TransactionKind> = {
  gasto: 'expense',
  gastos: 'expense',
  expense: 'expense',
  ingreso: 'income',
  ingresos: 'income',
  income: 'income',
  transferencia: 'transfer',
  transferencias: 'transfer',
  transfer: 'transfer',
  ajuste: 'adjustment',
  adjustment: 'adjustment',
};

const KIND_TO_PARAM: Record<TransactionKind, string> = {
  expense: 'gasto',
  income: 'ingreso',
  transfer: 'transferencia',
  adjustment: 'ajuste',
};

const STATUS_PARAMS: Record<string, TransactionStatus> = {
  pendiente: 'pending',
  pending: 'pending',
  confirmado: 'cleared',
  cleared: 'cleared',
};

const STATUS_TO_PARAM: Record<TransactionStatus, string> = { pending: 'pendiente', cleared: 'confirmado' };

const ISO = /^\d{4}-\d{2}-\d{2}$/;

function list(value: unknown): string[] {
  const raw = Array.isArray(value) ? value : value === undefined || value === null ? [] : [value];
  return raw
    .flatMap((item) => String(item).split(','))
    .map((item) => item.trim())
    .filter((item) => item !== '');
}

function single(value: unknown): string | null {
  const [first] = list(value);
  return first ?? null;
}

function cents(value: unknown): Cents | null {
  const text = single(value);
  if (text === null || !/^\d+$/.test(text)) {
    return null;
  }
  return Number(text);
}

function date(value: unknown): IsoDate | null {
  const text = single(value);
  return text !== null && ISO.test(text) ? text : null;
}

export function filtersFromParams(params: Params): TransactionFilters {
  const q = single(params[QUERY_KEYS.q]) ?? '';
  const from = date(params[QUERY_KEYS.from]);
  const to = date(params[QUERY_KEYS.to]);
  const rawPeriod = single(params[QUERY_KEYS.period]);
  let period: PeriodSelection;
  if (rawPeriod === 'todos') {
    period = 'all';
  } else if (rawPeriod === 'actual') {
    period = 'current';
  } else if (rawPeriod) {
    period = rawPeriod;
  } else {
    period = q !== '' || from !== null || to !== null ? 'all' : 'current';
  }
  const kinds = [...new Set(list(params[QUERY_KEYS.kinds]).map((kind) => KIND_PARAMS[kind]).filter(Boolean))];
  return {
    period,
    from,
    to,
    accountIds: list(params[QUERY_KEYS.accountIds]),
    categoryIds: list(params[QUERY_KEYS.categoryIds]),
    tags: list(params[QUERY_KEYS.tags]).map((tag) => tag.replace(/^#/, '').toLowerCase()),
    kinds,
    min: cents(params[QUERY_KEYS.min]),
    max: cents(params[QUERY_KEYS.max]),
    q,
    status: STATUS_PARAMS[single(params[QUERY_KEYS.status]) ?? ''] ?? null,
    debtId: single(params[QUERY_KEYS.debtId]),
    recurringRuleId: single(params[QUERY_KEYS.recurringRuleId]),
    contactId: single(params[QUERY_KEYS.contactId]),
  };
}

export function filtersToParams(filters: TransactionFilters): Params {
  const implicitAll = filters.q !== '' || filters.from !== null || filters.to !== null;
  let period: string | null;
  if (filters.period === 'all') {
    period = implicitAll ? null : 'todos';
  } else if (filters.period === 'current') {
    period = implicitAll ? 'actual' : null;
  } else {
    period = filters.period;
  }
  const params: Params = {
    [QUERY_KEYS.period]: period,
    [QUERY_KEYS.from]: filters.from,
    [QUERY_KEYS.to]: filters.to,
    [QUERY_KEYS.accountIds]: filters.accountIds.length ? filters.accountIds.join(',') : null,
    [QUERY_KEYS.categoryIds]: filters.categoryIds.length ? filters.categoryIds.join(',') : null,
    [QUERY_KEYS.tags]: filters.tags.length ? filters.tags.join(',') : null,
    [QUERY_KEYS.kinds]: filters.kinds.length ? filters.kinds.map((kind) => KIND_TO_PARAM[kind]).join(',') : null,
    [QUERY_KEYS.min]: filters.min,
    [QUERY_KEYS.max]: filters.max,
    [QUERY_KEYS.q]: filters.q !== '' ? filters.q : null,
    [QUERY_KEYS.status]: filters.status ? STATUS_TO_PARAM[filters.status] : null,
    [QUERY_KEYS.debtId]: filters.debtId,
    [QUERY_KEYS.recurringRuleId]: filters.recurringRuleId,
    [QUERY_KEYS.contactId]: filters.contactId,
  };
  return params;
}

export function filtersToApiQuery(filters: TransactionFilters, currentPeriodId: string | null): Record<string, QueryValue> {
  const periodId = filters.period === 'all' ? null : filters.period === 'current' ? currentPeriodId : filters.period;
  return {
    period_id: filters.from || filters.to ? null : periodId,
    from: filters.from,
    to: filters.to,
    account_id: filters.accountIds,
    category_id: filters.categoryIds,
    tag: filters.tags,
    kind: filters.kinds,
    min: filters.min,
    max: filters.max,
    q: filters.q.trim() || null,
    status: filters.status,
    debt_id: filters.debtId,
    recurring_rule_id: filters.recurringRuleId,
    contact_id: filters.contactId,
  };
}

export function activeFilterCount(filters: TransactionFilters): number {
  return [
    filters.accountIds.length > 0,
    filters.categoryIds.length > 0,
    filters.tags.length > 0,
    filters.kinds.length > 0,
    filters.min !== null || filters.max !== null,
    filters.status !== null,
    filters.from !== null || filters.to !== null,
    filters.debtId !== null || filters.recurringRuleId !== null || filters.contactId !== null,
  ].filter(Boolean).length;
}

export function sameFilters(left: TransactionFilters, right: TransactionFilters): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}
