import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { IsoDate } from '@shared/dates/dates';
import { firstValueFrom } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { Period } from './finance.models';

@Injectable({ providedIn: 'root' })
export class PeriodsService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: Period[] }>(() => {
    this.changes.version('periods')();
    return financeUrl('periods');
  });

  readonly all = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly current = computed(() => this.all().find((period) => period.is_current) ?? this.all()[0] ?? null);
  readonly loading = this.resource.isLoading;
  readonly loaded = computed(() => this.resource.hasValue());

  find(id: string | null | undefined): Period | undefined {
    return id ? this.all().find((period) => period.id === id) : undefined;
  }

  previousOf(id: string): Period | null {
    const periods = this.all();
    const index = periods.findIndex((period) => period.id === id);
    return index >= 0 ? (periods[index + 1] ?? null) : null;
  }

  nextOf(id: string): Period | null {
    const periods = this.all();
    const index = periods.findIndex((period) => period.id === id);
    return index > 0 ? periods[index - 1] : null;
  }

  reload(): void {
    this.resource.reload();
  }

  async open(startDate: IsoDate): Promise<Period> {
    const body = await firstValueFrom(this.http.post<{ data: Period }>(financeUrl('periods'), { start_date: startDate }));
    this.changes.notify('periods', 'budgets');
    return body.data;
  }

  async moveStart(id: string, startDate: IsoDate): Promise<Period> {
    const body = await firstValueFrom(
      this.http.patch<{ data: Period }>(financeUrl(`periods/${id}`), { start_date: startDate }),
    );
    this.changes.notify('periods', 'budgets');
    return body.data;
  }
}
