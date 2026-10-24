import { IsoDate } from '@shared/dates/dates';
import { Cents, ShareMode, SharesInput, SplitInput, Transaction, TransactionKind } from '../../data-access/finance.models';

export type EntryKind = TransactionKind;

export interface SharePreviewItem {
  contactId: string;
  name: string;
  percentage: number | null;
  amount: Cents | null;
}

export interface SplitDraft {
  categoryId: string | null;
  amount: Cents | null;
}

export interface TransactionSheetPreset {
  kind?: Exclude<EntryKind, 'adjustment'>;
  accountId?: string | null;
  toAccountId?: string | null;
  categoryId?: string | null;
  date?: IsoDate;
  payee?: string | null;
}

export interface TransactionSheetData {
  transaction?: Transaction | null;
  duplicateOf?: Transaction | null;
  preset?: TransactionSheetPreset;
}

export type TransactionSheetResult =
  | { action: 'saved'; transaction: Transaction }
  | { action: 'deleted'; transaction: Transaction }
  | { action: 'duplicate'; transaction: Transaction };

export function signedAmount(kind: EntryKind, magnitude: Cents): Cents {
  if (kind === 'expense') {
    return -Math.abs(magnitude);
  }
  if (kind === 'income' || kind === 'transfer') {
    return Math.abs(magnitude);
  }
  return magnitude;
}

export function splitRemaining(total: Cents, splits: SplitDraft[]): Cents {
  return Math.abs(total) - splits.reduce((sum, split) => sum + Math.abs(split.amount ?? 0), 0);
}

export function toSplitInputs(kind: EntryKind, splits: SplitDraft[]): SplitInput[] {
  return splits
    .filter((split): split is { categoryId: string; amount: Cents } => !!split.categoryId && !!split.amount)
    .map((split) => ({ category_id: split.categoryId, amount_cents: signedAmount(kind, split.amount) }));
}

export function previewShares(
  total: Cents,
  mode: ShareMode,
  includeSelf: boolean,
  items: SharePreviewItem[],
): { contactId: string; name: string; amount: Cents }[] {
  const absolute = Math.abs(total);
  if (items.length === 0 || absolute === 0) {
    return items.map((item) => ({ contactId: item.contactId, name: item.name, amount: 0 }));
  }
  if (mode === 'equal') {
    const parts = items.length + (includeSelf ? 1 : 0);
    const base = Math.floor(absolute / parts);
    const remainder = includeSelf ? 0 : absolute - base * parts;
    return items.map((item, index) => ({
      contactId: item.contactId,
      name: item.name,
      amount: base + (index < remainder ? 1 : 0),
    }));
  }
  if (mode === 'percentage') {
    return items.map((item) => ({
      contactId: item.contactId,
      name: item.name,
      amount: Math.round((absolute * Math.round((item.percentage ?? 0) * 100)) / 10_000),
    }));
  }
  return items.map((item) => ({ contactId: item.contactId, name: item.name, amount: item.amount ?? 0 }));
}

export function toSharesInput(mode: ShareMode, includeSelf: boolean, items: SharePreviewItem[]): SharesInput {
  return {
    mode,
    ...(mode === 'equal' ? { include_self: includeSelf } : {}),
    items: items.map((item) => ({
      contact_id: item.contactId,
      ...(mode === 'percentage' ? { percentage: item.percentage } : {}),
      ...(mode === 'amount' ? { amount_cents: item.amount } : {}),
    })),
  };
}

export function parseTagInput(raw: string): string[] {
  return raw
    .split(/[,\s]+/)
    .map((tag) => tag.trim().replace(/^#+/, '').toLowerCase())
    .filter((tag) => tag !== '');
}
