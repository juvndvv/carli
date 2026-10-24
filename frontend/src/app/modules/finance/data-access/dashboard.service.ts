import { httpResource } from '@angular/common/http';
import { inject, Injectable, Signal } from '@angular/core';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { Dashboard, FinanceSummary } from './finance.models';

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private readonly changes = inject(FinanceChanges);

  dashboardResource(periodId: Signal<string | null | undefined>) {
    return httpResource<{ data: Dashboard }>(() => {
      this.changes.any();
      const id = periodId();
      if (id === undefined) {
        return undefined;
      }
      const params: Record<string, string> = id ? { period_id: id } : {};
      return { url: financeUrl('dashboard'), params };
    });
  }

  summaryResource() {
    return httpResource<{ data: FinanceSummary }>(() => {
      this.changes.any();
      return financeUrl('summary');
    });
  }
}
