import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { FinanceSettings, FinanceSettingsInput, MutationMeta } from './finance.models';

@Injectable({ providedIn: 'root' })
export class FinanceSettingsService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: FinanceSettings }>(() => {
    this.changes.version('settings')();
    this.changes.version('transactions')();
    return financeUrl('settings');
  });

  readonly settings = computed(() => (this.resource.hasValue() ? this.resource.value().data : null));
  readonly loaded = computed(() => this.resource.hasValue());
  readonly preferredAccountId = computed(() => {
    const settings = this.settings();
    return settings?.default_account_id ?? settings?.last_used_account_id ?? null;
  });

  reload(): void {
    this.resource.reload();
  }

  async update(input: FinanceSettingsInput): Promise<{ settings: FinanceSettings; periodsChanged: boolean }> {
    const body = await firstValueFrom(
      this.http.patch<{ data: FinanceSettings; meta?: MutationMeta }>(financeUrl('settings'), input),
    );
    const periodsChanged = body.meta?.periods_changed ?? false;
    this.changes.notify('settings', ...(periodsChanged ? (['periods', 'budgets'] as const) : []));
    return { settings: body.data, periodsChanged };
  }
}
