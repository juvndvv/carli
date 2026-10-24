import { IsoDate } from '@shared/dates/dates';
import { Debt } from './debts.models';

export interface FinanceContact {
  id: string;
  name: string;
  notes: string | null;
  archived: boolean;
  balance_cents: number;
  shares_pending_cents: number;
  owed_to_me_cents: number;
  i_owe_cents: number;
}

export interface ContactShare {
  id: string;
  transaction_id: string;
  date: IsoDate;
  payee: string | null;
  description: string | null;
  transaction_amount_cents: number;
  amount_cents: number;
  settled: boolean;
  settled_at: string | null;
  settlement_transaction_id: string | null;
}

export interface FinanceContactDetail extends FinanceContact {
  shares: ContactShare[];
  debts: Debt[];
}

export interface ContactsMeta {
  owed_to_me_cents: number;
  i_owe_cents: number;
}

export interface ContactPayload {
  name: string;
  notes: string | null;
}

export interface SettleContactPayload {
  account_id: string;
  date: IsoDate;
}

export interface SettleContactResult {
  transaction: { id: string; amount_cents: number; date: IsoDate };
  transactions: { id: string; amount_cents: number; date: IsoDate }[];
  net_cents: number;
  contact: FinanceContact;
}

export type ContactBalanceTone = 'positive' | 'default' | 'muted';

export function contactBalanceLabel(balanceCents: number, formatMoney: (cents: number) => string): string {
  if (balanceCents > 0) {
    return `Te debe ${formatMoney(balanceCents)}`;
  }
  if (balanceCents < 0) {
    return `Le debes ${formatMoney(-balanceCents)}`;
  }
  return 'En paz';
}

export function contactBalanceTone(balanceCents: number): ContactBalanceTone {
  if (balanceCents > 0) {
    return 'positive';
  }
  return balanceCents < 0 ? 'default' : 'muted';
}

export function shareTitle(share: Pick<ContactShare, 'payee' | 'description'>): string {
  return share.payee || share.description || 'Gasto compartido';
}
