import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { firstValueFrom, map } from 'rxjs';
import { Debt, DebtPayload, DebtPayment, DebtPaymentPayload, DebtsMeta } from './debts.models';
import { FinanceAccountLookup, FinanceCategoryLookup } from './recurring.models';
import { fetchAccountLookups, fetchCategoryLookups, financeApiUrl } from './recurring.service';

@Injectable({ providedIn: 'root' })
export class DebtsService {
  private readonly http = inject(HttpClient);

  readonly debts = signal<Debt[]>([]);
  readonly meta = signal<DebtsMeta>({ owed_to_me_cents: 0, i_owe_cents: 0 });
  readonly loading = signal(false);
  readonly loaded = signal(false);
  readonly error = signal<string | null>(null);

  readonly openDebts = computed(() => this.debts().filter((debt) => !debt.closed));
  readonly closedDebts = computed(() => this.debts().filter((debt) => debt.closed));
  readonly iOwe = computed(() => this.openDebts().filter((debt) => debt.direction === 'i_owe'));
  readonly owedToMe = computed(() => this.openDebts().filter((debt) => debt.direction === 'owed_to_me'));

  async load(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const response = await firstValueFrom(
        this.http.get<{ data: Debt[]; meta: DebtsMeta }>(financeApiUrl('debts'), { params: { include_closed: '1' } }),
      );
      this.debts.set(response.data);
      this.meta.set(response.meta);
      this.loaded.set(true);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido cargar las deudas.'));
    } finally {
      this.loading.set(false);
    }
  }

  async create(payload: DebtPayload): Promise<Debt> {
    const response = await firstValueFrom(this.http.post<{ data: Debt }>(financeApiUrl('debts'), payload));
    await this.load();
    return response.data;
  }

  async update(id: string, patch: Partial<DebtPayload> & { closed?: boolean }): Promise<Debt> {
    const response = await firstValueFrom(this.http.patch<{ data: Debt }>(financeApiUrl(`debts/${id}`), patch));
    this.replace(response.data);
    void this.load();
    return response.data;
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete<void>(financeApiUrl(`debts/${id}`)));
    this.debts.update((debts) => debts.filter((debt) => debt.id !== id));
    void this.load();
  }

  payments(id: string): Promise<DebtPayment[]> {
    return firstValueFrom(
      this.http.get<{ data: DebtPayment[] }>(financeApiUrl(`debts/${id}/payments`)).pipe(map((response) => response.data)),
    );
  }

  async addPayment(id: string, payload: DebtPaymentPayload): Promise<{ payment: DebtPayment; debt: Debt }> {
    const response = await firstValueFrom(
      this.http.post<{ data: DebtPayment; meta: { debt: Debt } }>(financeApiUrl(`debts/${id}/payments`), payload),
    );
    this.replace(response.meta.debt);
    void this.load();
    return { payment: response.data, debt: response.meta.debt };
  }

  async deletePayment(transactionId: string): Promise<void> {
    await firstValueFrom(this.http.delete<unknown>(financeApiUrl(`transactions/${transactionId}`)));
    void this.load();
  }

  async restorePayment(transactionId: string): Promise<void> {
    await firstValueFrom(this.http.post<unknown>(financeApiUrl(`transactions/${transactionId}/restore`), {}));
    void this.load();
  }

  accounts(): Promise<FinanceAccountLookup[]> {
    return fetchAccountLookups(this.http);
  }

  categories(): Promise<FinanceCategoryLookup[]> {
    return fetchCategoryLookups(this.http, 'expense');
  }

  private replace(debt: Debt): void {
    this.debts.update((debts) => debts.map((current) => (current.id === debt.id ? debt : current)));
  }
}
