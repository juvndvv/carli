import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiBadge } from '@ui/badge/badge';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { DashboardService } from '../../data-access/dashboard.service';
import { daysLeftLabel, formatPercentRounded } from '../../data-access/finance-format';
import { FinanceSettingsService } from '../../data-access/finance-settings.service';
import { registerFinanceIcons } from '../../ui/finance-icons';

@Component({
  selector: 'app-finance-home-widget',
  imports: [UiSkeleton, UiBadge, MoneyPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (summary(); as data) {
      <div class="caption">Patrimonio neto</div>
      <div class="display num">{{ data.net_worth_cents | money }}</div>
      <div class="row wrap small muted facts">
        <span>
          Gastado en {{ data.period.short_name }}:
          <b class="num strong">{{ data.spent_cents | money }}</b>
        </span>
        @if (budgetState(); as state) {
          <ui-badge [tone]="state.tone" [icon]="state.icon">{{ state.label }}</ui-badge>
        }
      </div>
      <div class="small faint">{{ data.period.name }} · {{ daysLeft() }}</div>
    } @else if (resource.error()) {
      <div class="caption">Patrimonio neto</div>
      <p class="small muted">No se ha podido cargar el resumen de Finanzas.</p>
    } @else {
      <ui-skeleton width="40%" height="12px" />
      <ui-skeleton width="70%" height="36px" />
      <ui-skeleton width="55%" height="14px" />
    }
  `,
  styles: `
    :host {
      display: flex;
      flex-direction: column;
      gap: 4px;
      margin-top: 16px;
    }
    .facts {
      gap: 16px;
      margin-top: 4px;
    }
    .strong {
      color: var(--text);
    }
    .faint {
      margin-top: 8px;
    }
  `,
})
export class FinanceHomeWidget {
  private readonly settings = inject(FinanceSettingsService);
  protected readonly resource = inject(DashboardService).summaryResource();
  protected readonly summary = computed(() => (this.resource.hasValue() ? this.resource.value().data : null));
  protected readonly daysLeft = computed(() => daysLeftLabel(this.summary()?.period.days_remaining ?? 0));
  protected readonly budgetState = computed(() => {
    const budget = this.summary()?.budget;
    if (!budget || budget.budgeted_cents === 0 || budget.percent_bp === null) {
      return null;
    }
    const threshold = (this.settings.settings()?.budget_warning_threshold ?? 80) * 100;
    if (budget.percent_bp > 10_000) {
      return { tone: 'negative' as const, icon: 'triangle-alert', label: 'Presupuesto superado' };
    }
    if (budget.percent_bp >= threshold) {
      return { tone: 'warning' as const, icon: 'triangle-alert', label: `${formatPercentRounded(budget.percent_bp)} del presupuesto` };
    }
    return { tone: 'neutral' as const, icon: 'gauge', label: `${formatPercentRounded(budget.percent_bp)} del presupuesto` };
  });

  constructor() {
    registerFinanceIcons();
  }
}
