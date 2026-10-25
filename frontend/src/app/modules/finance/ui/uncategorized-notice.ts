import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { formatMoney } from '@shared/money/money';
import { UiIcon } from '@ui/icon/icon';
import { UncategorizedSummary } from '../data-access/finance.models';

export function uncategorizedMessage(summary: UncategorizedSummary | null | undefined): { amount: string; detail: string } | null {
  if (!summary || summary.expense_cents === 0) {
    return null;
  }
  const movements = summary.count === 1 ? '1 gasto' : `${summary.count} gastos`;
  return {
    amount: `${formatMoney(summary.expense_cents)} sin categorizar`,
    detail: `${movements} aún no cuenta${summary.count === 1 ? '' : 'n'} en ningún presupuesto.`,
  };
}

@Component({
  selector: 'fin-uncategorized-notice',
  imports: [RouterLink, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (message(); as text) {
      <div class="notice" role="status">
        <ui-icon name="circle-dashed" />
        <div class="body">
          <strong class="num">{{ text.amount }}</strong>
          <span class="small">{{ text.detail }}</span>
        </div>
        <a class="link small" routerLink="/finanzas/movimientos" [queryParams]="query()">Revisar</a>
      </div>
    }
  `,
  styles: `
    :host {
      display: block;
    }
    :host:empty {
      display: none;
    }
    .notice {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 16px;
      border-radius: var(--r-md);
      background: var(--warning-soft);
      color: var(--warning);
    }
    .body {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      color: var(--text);
    }
    strong {
      font-weight: 600;
      color: var(--warning);
    }
    .link {
      color: var(--text);
      font-weight: 500;
      white-space: nowrap;
    }
  `,
})
export class FinUncategorizedNotice {
  readonly summary = input<UncategorizedSummary | null | undefined>(null);
  readonly periodId = input<string | null>(null);

  protected readonly message = computed(() => uncategorizedMessage(this.summary()));
  protected readonly query = computed(() => {
    const periodId = this.periodId();
    return periodId ? { sin_categoria: '1', periodo: periodId } : { sin_categoria: '1' };
  });
}
