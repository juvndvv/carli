import { httpResource } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { addDays, formatShortDate } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { BudgetsService } from '../../data-access/budgets.service';
import { FALLBACK_CATEGORY_ICON } from '../../data-access/categories.service';
import { financeUrl } from '../../data-access/finance-api';
import { FinanceChanges } from '../../data-access/finance-changes';
import { FinanceSettingsService } from '../../data-access/finance-settings.service';
import { budgetLimit, budgetUsageLabel, formatPercentRounded } from '../../data-access/finance-format';
import { BudgetOverview, BudgetRow, BudgetStatus } from '../../data-access/finance.models';
import { PeriodsService } from '../../data-access/periods.service';
import { FinBudgetLine } from '../../ui/budget-line';
import { FinPeriodSelector } from '../../ui/period-selector';
import { BudgetEditorData, BudgetEditorDialog } from './budget-editor-dialog';

const STATUS_BADGES: Record<BudgetStatus, { tone: 'positive' | 'warning' | 'negative'; icon: string }> = {
  ok: { tone: 'positive', icon: 'check' },
  warning: { tone: 'warning', icon: 'triangle-alert' },
  exceeded: { tone: 'negative', icon: 'circle-x' },
};

@Component({
  selector: 'app-finance-budgets-page',
  imports: [UiPageHeader, UiCard, UiStat, UiButton, UiBadge, UiIcon, UiSkeleton, UiEmptyState, FinPeriodSelector, FinBudgetLine],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Presupuestos" crumb="Finanzas">
      <fin-period-selector [periods]="periods.all()" [value]="period()?.id ?? null" (valueChange)="selectPeriod($event)" />
    </ui-page-header>

    @if (overview(); as data) {
      <div class="grid-cards g-3">
        <ui-stat label="Presupuestado" [value]="money(budgeted())" [delta]="data.data.length === 1 ? '1 categoría' : data.data.length + ' categorías'" />
        <ui-stat label="Gastado" [value]="money(data.meta.totals.spent_cents)" [delta]="spentDelta()" />
        @if (data.meta.period.is_current) {
          <ui-stat
            label="Proyección fin de periodo"
            [value]="money(data.meta.totals.projected_cents)"
            [tone]="projectionOver() ? 'warning' : 'default'"
            [delta]="projectionDelta()"
            [deltaIcon]="projectionOver() ? 'triangle-alert' : 'circle-check'"
            [deltaTone]="projectionOver() ? 'warning' : 'muted'"
          />
        } @else {
          <ui-stat
            label="Resultado"
            [value]="money(data.meta.totals.remaining_cents)"
            [tone]="data.meta.totals.remaining_cents < 0 ? 'negative' : 'positive'"
            [delta]="data.meta.totals.remaining_cents < 0 ? 'Te pasaste del total' : 'Te sobró del total'"
          />
        }
      </div>

      <ui-card class="section" heading="Por categoría">
        <div card-actions class="row actions">
          @if (data.meta.previous_period; as previous) {
            <button ui-button type="button" variant="ghost" size="sm" icon="copy" [loading]="copying()" (click)="copyFrom(previous.id, previous.short_name)">
              <span class="d-only">Copiar de {{ previous.short_name }}</span>
            </button>
          }
          <button ui-button type="button" variant="secondary" size="sm" icon="pencil" (click)="edit(data)">
            <span class="d-only">Editar</span>
          </button>
        </div>
        @if (data.data.length > 0) {
          <div class="ui-list">
            @for (row of sorted(); track row.id) {
              <button type="button" class="budget" (click)="openTransactions(row)">
                <span class="ico"><ui-icon [name]="row.category.icon ?? fallbackIcon" /></span>
                <fin-budget-line class="body" [row]="row" [warnAt]="warnAt()" [showProjection]="data.meta.period.is_current" />
                <span class="badge-col">
                  <ui-badge [tone]="badge(row).tone" [icon]="badge(row).icon">{{ percent(row) }}</ui-badge>
                </span>
              </button>
            }
          </div>
        } @else {
          <ui-empty-state
            icon="gauge"
            heading="Aún no hay presupuestos en este periodo"
            description="Pon un límite a cada categoría y te avisaremos al llegar al {{ threshold() }} % y al superarlo."
          >
            @if (data.meta.previous_period; as previous) {
              <button ui-button type="button" variant="secondary" icon="copy" (click)="copyFrom(previous.id, previous.short_name)">
                Copiar de {{ previous.short_name }}
              </button>
            }
            <button ui-button type="button" variant="primary" icon="plus" (click)="edit(data)">Crear presupuestos</button>
          </ui-empty-state>
        }
      </ui-card>
    } @else if (resource.error()) {
      <ui-card>
        <ui-empty-state icon="circle-alert" heading="No se han podido cargar los presupuestos" description="Comprueba tu conexión e inténtalo de nuevo.">
          <button ui-button type="button" variant="secondary" (click)="resource.reload()">Reintentar</button>
        </ui-empty-state>
      </ui-card>
    } @else {
      <div class="grid-cards g-3">
        @for (item of [1, 2, 3]; track item) {
          <ui-card><ui-skeleton width="50%" height="13px" /><ui-skeleton width="70%" height="28px" class="gap" /></ui-card>
        }
      </div>
      <ui-card class="section"><ui-skeleton height="200px" /></ui-card>
    }
  `,
  styles: `
    .section {
      margin-top: 16px;
    }
    .gap {
      margin-top: 8px;
    }
    .actions {
      gap: 8px;
    }
    .budget {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      padding: 14px 4px;
      border: 0;
      border-bottom: 1px solid var(--border);
      background: none;
      color: var(--text);
      text-align: left;
      font: inherit;
      width: 100%;
      border-radius: 0;
    }
    .budget:last-child {
      border-bottom: 0;
    }
    .budget:hover {
      background: var(--surface-2);
      border-radius: var(--r-md);
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      flex: none;
      background: var(--surface-2);
      color: var(--text);
    }
    .body {
      flex: 1;
    }
    .badge-col {
      width: 84px;
      display: flex;
      justify-content: flex-end;
      flex: none;
    }
  `,
})
export class BudgetsPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly budgets = inject(BudgetsService);
  private readonly changes = inject(FinanceChanges);
  private readonly settings = inject(FinanceSettingsService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);
  protected readonly periods = inject(PeriodsService);
  protected readonly fallbackIcon = FALLBACK_CATEGORY_ICON;
  protected readonly copying = signal(false);

  private readonly params = toSignal(this.route.queryParamMap, { initialValue: this.route.snapshot.queryParamMap });
  private readonly requestedPeriod = computed(() => this.params().get('periodo'));

  protected readonly resource = httpResource<BudgetOverview>(() => {
    this.changes.version('budgets')();
    this.changes.version('transactions')();
    const id = this.requestedPeriod();
    const params: Record<string, string> = id ? { period_id: id } : {};
    return { url: financeUrl('budgets'), params };
  });
  protected readonly overview = computed(() => (this.resource.hasValue() ? this.resource.value() : null));
  protected readonly period = computed(() => this.overview()?.meta.period ?? null);
  protected readonly threshold = computed(() => this.settings.settings()?.budget_warning_threshold ?? 80);
  protected readonly warnAt = computed(() => this.threshold() / 100);
  protected readonly sorted = computed(() =>
    [...(this.overview()?.data ?? [])].sort((left, right) => left.category.sort_key - right.category.sort_key),
  );
  protected readonly budgeted = computed(() => (this.overview()?.data ?? []).reduce((sum, row) => sum + budgetLimit(row), 0));
  protected readonly projectionOver = computed(() => {
    const totals = this.overview()?.meta.totals;
    return !!totals && this.budgeted() > 0 && totals.projected_cents > this.budgeted();
  });
  protected readonly spentDelta = computed(() => {
    const data = this.overview();
    if (!data) {
      return null;
    }
    const budgeted = this.budgeted();
    const percent = budgeted > 0 ? `${formatPercentRounded(Math.round((data.meta.totals.spent_cents * 10_000) / budgeted))} del total` : null;
    const period = data.meta.period;
    const next = period.is_current ? this.nextPayrollLabel() : null;
    return [percent, next].filter(Boolean).join(' · ') || null;
  });
  protected readonly projectionDelta = computed(() => {
    const totals = this.overview()?.meta.totals;
    if (!totals || this.budgeted() === 0) {
      return 'Según tu ritmo de gasto';
    }
    const gap = totals.projected_cents - this.budgeted();
    return gap > 0 ? `Superarías el total en ${formatMoney(gap)}` : `Te sobrarían ${formatMoney(-gap)}`;
  });

  protected money(cents: number): string {
    return formatMoney(cents);
  }

  protected percent(row: BudgetRow): string {
    return budgetUsageLabel(row);
  }

  protected badge(row: BudgetRow): { tone: 'positive' | 'warning' | 'negative'; icon: string } {
    return STATUS_BADGES[row.status];
  }

  protected selectPeriod(id: string | null): void {
    const period = this.periods.find(id);
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { periodo: period && !period.is_current ? period.id : null },
      replaceUrl: true,
    });
  }

  protected openTransactions(row: BudgetRow): void {
    const period = this.period();
    void this.router.navigate(['/finanzas/movimientos'], {
      queryParams: {
        categoria: row.category_id,
        periodo: period && !period.is_current ? period.id : null,
        tipo: 'gasto',
      },
    });
  }

  protected async edit(data: BudgetOverview): Promise<void> {
    const ref = this.dialogs.open<BudgetEditorDialog, BudgetEditorData, BudgetOverview>(BudgetEditorDialog, {
      data: { period: data.meta.period, rows: data.data },
      size: 'lg',
    });
    if (await firstValueFrom(ref.closed)) {
      this.toast.show('Presupuestos guardados');
    }
  }

  protected async copyFrom(fromPeriodId: string, label: string): Promise<void> {
    const target = this.period();
    if (!target) {
      return;
    }
    this.copying.set(true);
    try {
      const result = await this.budgets.copy(fromPeriodId, target.id);
      const copied = result.meta.copied ?? 0;
      this.toast.show(
        copied === 0
          ? `No había nada nuevo que copiar de ${label}`
          : copied === 1
            ? `1 presupuesto copiado de ${label}`
            : `${copied} presupuestos copiados de ${label}`,
      );
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se han podido copiar los presupuestos.'));
    } finally {
      this.copying.set(false);
    }
  }

  private nextPayrollLabel(): string | null {
    const period = this.period();
    const settings = this.settings.settings();
    if (!period?.expected_end_date) {
      return null;
    }
    const next = formatShortDate(addDays(period.expected_end_date, 1));
    return settings?.period_mode === 'calendar' ? `termina el ${formatShortDate(period.expected_end_date)}` : `nómina prevista el ${next}`;
  }
}
