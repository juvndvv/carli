import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { firstValueFrom, map } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { Account, AccountInput, Cents, ReconcileResult } from './finance.models';

interface AccountsResponse {
  data: Account[];
  meta: { net_worth_cents: Cents };
}

@Injectable({ providedIn: 'root' })
export class AccountsService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<AccountsResponse>(() => {
    this.changes.version('accounts')();
    return { url: financeUrl('accounts'), params: { include_archived: 1 } };
  });

  readonly all = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly active = computed(() => this.all().filter((account) => !account.archived));
  readonly archived = computed(() => this.all().filter((account) => account.archived));
  readonly netWorth = computed(() => (this.resource.hasValue() ? this.resource.value().meta.net_worth_cents : null));
  readonly loading = this.resource.isLoading;
  readonly loaded = computed(() => this.resource.hasValue());
  readonly error = this.resource.error;

  find(id: string | null | undefined): Account | undefined {
    return id ? this.all().find((account) => account.id === id) : undefined;
  }

  reload(): void {
    this.resource.reload();
  }

  get(id: string): Promise<Account> {
    return firstValueFrom(this.http.get<{ data: Account }>(financeUrl(`accounts/${id}`)).pipe(map((body) => body.data)));
  }

  async create(input: AccountInput): Promise<Account> {
    const body = await firstValueFrom(this.http.post<{ data: Account }>(financeUrl('accounts'), input));
    this.changes.notify('accounts');
    return body.data;
  }

  async update(id: string, input: Partial<AccountInput>): Promise<Account> {
    const body = await firstValueFrom(this.http.patch<{ data: Account }>(financeUrl(`accounts/${id}`), input));
    this.changes.notify('accounts');
    return body.data;
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(financeUrl(`accounts/${id}`)));
    this.changes.notify('accounts');
  }

  async reconcile(id: string, actualBalanceCents: Cents, date?: string): Promise<ReconcileResult> {
    const body = await firstValueFrom(
      this.http.post<{ data: ReconcileResult }>(financeUrl(`accounts/${id}/reconcile`), {
        actual_balance_cents: actualBalanceCents,
        ...(date ? { date } : {}),
      }),
    );
    this.changes.notifyTransactions();
    return body.data;
  }
}
