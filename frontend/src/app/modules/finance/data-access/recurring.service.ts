import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { apiUrl, firstValidationMessage } from '@core/http/api';
import { firstValueFrom, map } from 'rxjs';
import {
  ConfirmRecurringPayload,
  ConfirmRecurringResult,
  FinanceAccountLookup,
  FinanceCategoryKind,
  FinanceCategoryLookup,
  FinanceReminderSettings,
  RecurringRule,
  RecurringRulePayload,
  RecurringRulesMeta,
} from './recurring.models';

export const financeApiUrl = (path: string): string => apiUrl(`finance/${path.replace(/^\//, '')}`);

export function fetchAccountLookups(http: HttpClient): Promise<FinanceAccountLookup[]> {
  return firstValueFrom(
    http.get<{ data: FinanceAccountLookup[] }>(financeApiUrl('accounts')).pipe(map((response) => response.data)),
  );
}

export function fetchCategoryLookups(http: HttpClient, kind?: FinanceCategoryKind): Promise<FinanceCategoryLookup[]> {
  const params: Record<string, string> = { flat: '1' };
  if (kind) {
    params['kind'] = kind;
  }
  return firstValueFrom(
    http
      .get<{ data: FinanceCategoryLookup[] }>(financeApiUrl('categories'), { params })
      .pipe(map((response) => response.data.filter((category) => !category.archived))),
  );
}

interface RecurringIndexResponse {
  data: RecurringRule[];
  meta: RecurringRulesMeta;
}

@Injectable({ providedIn: 'root' })
export class RecurringService {
  private readonly http = inject(HttpClient);

  readonly rules = signal<RecurringRule[]>([]);
  readonly meta = signal<RecurringRulesMeta | null>(null);
  readonly loading = signal(false);
  readonly loaded = signal(false);
  readonly error = signal<string | null>(null);
  readonly reminderDays = signal<number | null>(null);

  readonly pendingCount = computed(() => this.rules().filter((rule) => rule.pending_transaction !== null).length);
  readonly subscriptions = computed(() => this.rules().filter((rule) => rule.is_subscription && !rule.cancelled));

  async load(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const response = await firstValueFrom(
        this.http.get<RecurringIndexResponse>(financeApiUrl('recurring-rules'), { params: { include_cancelled: '1' } }),
      );
      this.rules.set(response.data);
      this.meta.set(response.meta);
      this.loaded.set(true);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido cargar los recurrentes.'));
    } finally {
      this.loading.set(false);
    }
  }

  async loadReminderSettings(): Promise<void> {
    try {
      const response = await firstValueFrom(
        this.http.get<{ data: FinanceReminderSettings }>(financeApiUrl('settings')),
      );
      this.reminderDays.set(response.data.remind_days_before);
    } catch {
      this.reminderDays.set(null);
    }
  }

  async create(payload: RecurringRulePayload): Promise<RecurringRule> {
    const response = await firstValueFrom(
      this.http.post<{ data: RecurringRule }>(financeApiUrl('recurring-rules'), payload),
    );
    await this.load();
    return response.data;
  }

  async update(id: string, patch: Partial<RecurringRulePayload> & { cancelled?: boolean }): Promise<RecurringRule> {
    const response = await firstValueFrom(
      this.http.patch<{ data: RecurringRule }>(financeApiUrl(`recurring-rules/${id}`), patch),
    );
    this.replace(response.data);
    void this.load();
    return response.data;
  }

  setCancelled(id: string, cancelled: boolean): Promise<RecurringRule> {
    return this.update(id, { cancelled });
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete<void>(financeApiUrl(`recurring-rules/${id}`)));
    this.rules.update((rules) => rules.filter((rule) => rule.id !== id));
    void this.load();
  }

  async confirm(id: string, payload: ConfirmRecurringPayload): Promise<ConfirmRecurringResult> {
    const response = await firstValueFrom(
      this.http.post<{ data: ConfirmRecurringResult }>(financeApiUrl(`recurring-rules/${id}/confirm`), payload),
    );
    this.replace(response.data.rule);
    void this.load();
    return response.data;
  }

  accounts(): Promise<FinanceAccountLookup[]> {
    return fetchAccountLookups(this.http);
  }

  categories(kind?: FinanceCategoryKind): Promise<FinanceCategoryLookup[]> {
    return fetchCategoryLookups(this.http, kind);
  }

  private replace(rule: RecurringRule): void {
    this.rules.update((rules) => rules.map((current) => (current.id === rule.id ? rule : current)));
  }
}
