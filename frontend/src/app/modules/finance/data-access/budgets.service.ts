import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { BudgetOverview, BudgetUpsertItem } from './finance.models';

@Injectable({ providedIn: 'root' })
export class BudgetsService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  readonly version = this.changes.version('budgets');

  overviewUrl(periodId: string | null): { url: string; params: Record<string, string> } {
    return { url: financeUrl('budgets'), params: periodId ? { period_id: periodId } : {} };
  }

  overview(periodId: string | null): Promise<BudgetOverview> {
    const { url, params } = this.overviewUrl(periodId);
    return firstValueFrom(this.http.get<BudgetOverview>(url, { params }));
  }

  async upsert(periodId: string | null, budgets: BudgetUpsertItem[]): Promise<BudgetOverview> {
    const body = await firstValueFrom(
      this.http.put<BudgetOverview>(financeUrl('budgets'), { ...(periodId ? { period_id: periodId } : {}), budgets }),
    );
    this.changes.notify('budgets');
    return body;
  }

  async copy(fromPeriodId: string, toPeriodId: string): Promise<BudgetOverview> {
    const body = await firstValueFrom(
      this.http.post<BudgetOverview>(financeUrl('budgets/copy'), {
        from_period_id: fromPeriodId,
        to_period_id: toPeriodId,
      }),
    );
    this.changes.notify('budgets');
    return body;
  }
}
