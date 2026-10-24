import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { financeUrl, QueryValue, toHttpParams, toQueryString } from './finance-api';
import { FinanceChanges } from './finance-changes';
import {
  BulkUpdateInput,
  MutationMeta,
  Transaction,
  TransactionInput,
  TransactionPage,
  TransferInput,
  TransferResult,
} from './finance.models';

export interface SavedTransaction {
  transaction: Transaction;
  periodsChanged: boolean;
}

@Injectable({ providedIn: 'root' })
export class TransactionsService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  list(query: Record<string, QueryValue>, cursor?: string | null, perPage = 50): Promise<TransactionPage> {
    return firstValueFrom(
      this.http.get<TransactionPage>(financeUrl('transactions'), {
        params: toHttpParams({ ...query, per_page: perPage, cursor: cursor ?? null }),
      }),
    );
  }

  async get(id: string): Promise<Transaction> {
    const body = await firstValueFrom(this.http.get<{ data: Transaction }>(financeUrl(`transactions/${id}`)));
    return body.data;
  }

  async create(input: TransactionInput): Promise<SavedTransaction> {
    const body = await firstValueFrom(
      this.http.post<{ data: Transaction; meta: MutationMeta }>(financeUrl('transactions'), input),
    );
    this.changes.notifyTransactions();
    return { transaction: body.data, periodsChanged: body.meta?.periods_changed ?? false };
  }

  async update(id: string, input: TransactionInput | Partial<TransferInput>): Promise<SavedTransaction> {
    const body = await firstValueFrom(
      this.http.patch<{ data: Transaction; meta: MutationMeta }>(financeUrl(`transactions/${id}`), input),
    );
    this.changes.notifyTransactions();
    return { transaction: body.data, periodsChanged: body.meta?.periods_changed ?? false };
  }

  async remove(id: string): Promise<boolean> {
    const body = await firstValueFrom(this.http.delete<{ meta?: MutationMeta }>(financeUrl(`transactions/${id}`)));
    this.changes.notifyTransactions();
    return body?.meta?.periods_changed ?? false;
  }

  async restore(id: string): Promise<SavedTransaction> {
    const body = await firstValueFrom(
      this.http.post<{ data: Transaction; meta: MutationMeta }>(financeUrl(`transactions/${id}/restore`), {}),
    );
    this.changes.notifyTransactions();
    return { transaction: body.data, periodsChanged: body.meta?.periods_changed ?? false };
  }

  async bulkUpdate(input: BulkUpdateInput): Promise<number> {
    const body = await firstValueFrom(
      this.http.patch<{ data: { updated: number } }>(financeUrl('transactions/bulk'), input),
    );
    this.changes.notifyTransactions();
    return body.data.updated;
  }

  async transfer(input: TransferInput): Promise<TransferResult> {
    const body = await firstValueFrom(this.http.post<{ data: TransferResult }>(financeUrl('transfers'), input));
    this.changes.notifyTransactions();
    return body.data;
  }

  exportUrl(query: Record<string, QueryValue>): string {
    const search = toQueryString(query);
    return `${financeUrl('transactions/export.csv')}${search ? `?${search}` : ''}`;
  }
}

export function duplicateInput(transaction: Transaction, date: string): TransactionInput {
  const kind = transaction.kind === 'transfer' ? 'expense' : transaction.kind;
  return {
    account_id: transaction.account_id,
    kind,
    amount_cents: transaction.amount_cents,
    date,
    category_id: transaction.splits.length > 0 ? null : transaction.category_id,
    payee: transaction.payee,
    description: transaction.description,
    notes: transaction.notes,
    tags: [...transaction.tags],
    splits:
      transaction.splits.length > 0
        ? transaction.splits.map((split) => ({ category_id: split.category_id, amount_cents: split.amount_cents }))
        : null,
    shares:
      transaction.shares.length > 0
        ? {
            mode: 'amount',
            items: transaction.shares.map((share) => ({ contact_id: share.contact_id, amount_cents: share.amount_cents })),
          }
        : null,
  };
}
