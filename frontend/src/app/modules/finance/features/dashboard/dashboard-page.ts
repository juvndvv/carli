import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { formatMoney, formatMoneyCompact } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { formatShortDate, todayIso, daysBetween } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiChart, UiChartColor, UiChartSlot } from '@ui/chart/chart';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { StatTone, UiStat } from '@ui/stat/stat';
import { AccountsService } from '../../data-access/accounts.service';
import { DashboardService } from '../../data-access/dashboard.service';
import { FinanceSettingsService } from '../../data-access/finance-settings.service';
import { chartSlot, daysLeftLabel, formatBasisPoints, inDaysLabel } from '../../data-access/finance-format';
import { BasisPoints, Dashboard, DashboardCategoryGroup, Transaction } from '../../data-access/finance.models';
import { PeriodsService } from '../../data-access/periods.service';
import { FinBudgetLine } from '../../ui/budget-line';
import { FinPeriodSelector } from '../../ui/period-selector';
import { FinTransactionRow } from '../../ui/transaction-row';
import { FinUncategorizedNotice } from '../../ui/uncategorized-notice';
import { TransactionSheetLauncher } from '../transactions/transaction-sheet.launcher';

export interface DonutSlice {
  label: string;
  amount: number;
  color: UiChartColor;
  percent: string;
}

const MAX_SLICES = 8;

export function buildDonut(groups: DashboardCategoryGroup[]): DonutSlice[] {
  const total = groups.reduce((sum, group) => sum + group.amount_cents, 0);
  const sorted = [...groups].sort((left, right) => right.amount_cents - left.amount_cents);
  const head = sorted.length > MAX_SLICES ? sorted.slice(0, MAX_SLICES - 1) : sorted;
  const tail = sorted.length > MAX_SLICES ? sorted.slice(MAX_SLICES - 1) : [];
  const used = new Set<UiChartSlot>();
  const wanted = head.map((group) => chartSlot(group.color));
  const slots: (UiChartSlot | null)[] = wanted.map((slot) => {
    if (slot !== null && !used.has(slot)) {
      used.add(slot);
      return slot;
    }
    return null;
  });
  const free = ([1, 2, 3, 4, 5, 6, 7, 8] as UiChartSlot[]).filter((slot) => !used.has(slot));
  const percent = (amount: number) => (total > 0 ? `${Math.round((amount / total) * 100)} %` : '0 %');
  const slices: DonutSlice[] = head.map((group, index) => ({
    label: group.name,
    amount: group.amount_cents,
    color: slots[index] ?? free.shift() ?? 'text-3',
    percent: percent(group.amount_cents),
  }));
  if (tail.length > 0) {
    const amount = tail.reduce((sum, group) => sum + group.amount_cents, 0);
    slices.push({ label: 'Otros', amount, color: 'text-3', percent: percent(amount) });
  }
  return slices;
}

function deltaTone(value: BasisPoints | null | undefined, higherIsBetter: boolean): StatTone {
  if (value === null || value === undefined || Math.abs(value) < 50) {
    return 'muted';
  }
  return value > 0 === higherIsBetter ? 'positive' : 'negative';
}

function deltaIcon(value: BasisPoints | null | undefined): string {
  if (value === null || value === undefined || Math.abs(value) < 50) {
    return 'minus';
  }
  return value > 0 ? 'trending-up' : 'trending-down';
}

@Component({
  selector: 'app-finance-dashboard-page',
  imports: [
    RouterLink,
    UiPageHeader,
    UiCard,
    UiStat,
    UiChart,
    UiListItem,
    UiSkeleton,
    UiEmptyState,
    UiButton,
    MoneyPipe,
    FinPeriodSelector,
    FinBudgetLine,
    FinTransactionRow,
    FinUncategorizedNotice,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Resumen" [crumb]="crumb()">
      <fin-period-selector [periods]="periods.all()" [value]="selectedPeriodId()" (valueChange)="selectPeriod($event)" />
    </ui-page-header>

    @if (dashboard(); as data) {
      @if (noAccounts()) {
        <ui-card>
          <ui-empty-state
            icon="wallet"
            heading="Empieza por tus cuentas"
            description="Añade tu cuenta corriente, tus tarjetas o el efectivo y apunta tu primer movimiento para ver aquí tu resumen."
          >
            <a ui-button variant="primary" icon="plus" routerLink="/finanzas/cuentas">Añadir cuenta</a>
          </ui-empty-state>
        </ui-card>
      } @else {
        <div class="grid-cards g-4">
          <ui-stat
            label="Patrimonio neto"
            icon="landmark"
            [value]="money(data.net_worth_cents)"
            [delta]="netWorthDelta()"
            [deltaIcon]="(data.net_worth_delta_cents ?? 0) >= 0 ? 'trending-up' : 'trending-down'"
            [deltaTone]="(data.net_worth_delta_cents ?? 0) >= 0 ? 'positive' : 'negative'"
          />
          <ui-stat
            label="Ingresos"
            icon="arrow-down-left"
            tone="positive"
            [value]="money(data.income_cents)"
            [delta]="percentDelta(data.deltas_bp?.income)"
            [deltaIcon]="deltaIcon(data.deltas_bp?.income)"
            [deltaTone]="deltaTone(data.deltas_bp?.income, true)"
          />
          <ui-stat
            label="Gastos"
            icon="arrow-up-right"
            [value]="money(data.expense_cents)"
            [delta]="percentDelta(data.deltas_bp?.expense)"
            [deltaIcon]="deltaIcon(data.deltas_bp?.expense)"
            [deltaTone]="deltaTone(data.deltas_bp?.expense, false)"
          />
          <ui-stat
            label="Ahorro del periodo"
            icon="piggy-bank"
            [tone]="data.savings_cents < 0 ? 'negative' : 'default'"
            [value]="money(data.savings_cents)"
            [delta]="savingsRate()"
          />
        </div>

        <fin-uncategorized-notice class="section" [summary]="data.uncategorized" [periodId]="pastPeriodId()" />

        <div class="grid-cards g-main section">
          <ui-card heading="Ingresos y gastos">
            @if (history().labels.length > 0) {
              <ui-chart
                type="bar"
                ariaLabel="Ingresos y gastos de los últimos periodos"
                [labels]="history().labels"
                [series]="history().flows"
              />
            } @else {
              <p class="small muted">Aún no hay periodos anteriores con los que comparar.</p>
            }
          </ui-card>
          <ui-card heading="Gasto por categoría">
            @if (donut().length > 0) {
              <div class="donut-host">
              <div class="donut-wrap">
                <ui-chart
                  class="donut"
                  type="doughnut"
                  ariaLabel="Gasto por categoría"
                  categoryHeader="Categoría"
                  centerLabel="Gastado"
                  [centerValue]="donutTotal()"
                  [labels]="donutLabels()"
                  [series]="donutSeries()"
                  [colors]="donutColors()"
                  [height]="160"
                  [showLegend]="false"
                />
                <ul class="donut-legend" aria-label="Categorías con más gasto">
                  @for (slice of donut().slice(0, 6); track slice.label) {
                    <li class="row between small">
                      <span class="row legend-name">
                        <span class="legend-swatch" [style.background]="'var(' + colorVar(slice.color) + ')'"></span>
                        {{ slice.label }}
                      </span>
                      <span class="num">{{ slice.amount | money }}</span>
                    </li>
                  }
                </ul>
              </div>
              </div>
            } @else {
              <ui-empty-state icon="chart-pie" heading="Sin gastos en este periodo" description="Cuando apuntes gastos verás aquí en qué se va el dinero." />
            }
          </ui-card>
        </div>

        <div class="grid-cards g-3 section">
          <ui-card heading="Presupuestos">
            <a card-actions class="small link" [routerLink]="'/finanzas/presupuestos'" [queryParams]="periodQuery()">Ver todos</a>
            @if (data.budgets.top.length > 0) {
              <div class="stack budgets">
                @for (row of data.budgets.top; track row.id) {
                  <fin-budget-line [row]="row" [warnAt]="warnAt()" />
                }
              </div>
            } @else {
              <ui-empty-state icon="gauge" heading="Sin presupuestos" description="Pon un límite a las categorías en las que más gastas.">
                <a ui-button size="sm" variant="secondary" [routerLink]="'/finanzas/presupuestos'" [queryParams]="periodQuery()">Crear presupuestos</a>
              </ui-empty-state>
            }
          </ui-card>

          <ui-card heading="Próximos cargos">
            <a card-actions class="small link" routerLink="/finanzas/recurrentes">Ver todos</a>
            @if (data.upcoming.length > 0) {
              <div class="ui-list">
                @for (charge of data.upcoming; track charge.rule_id + charge.date) {
                  <ui-list-item
                    [heading]="charge.name"
                    [subtitle]="shortDate(charge.date) + ' · ' + inDays(charge.date)"
                    [icon]="charge.category?.icon ?? 'repeat'"
                    [value]="signed(charge.amount_cents)"
                    [valueTone]="charge.amount_cents > 0 ? 'positive' : 'default'"
                  />
                }
              </div>
            } @else {
              <p class="small muted">No hay cargos recurrentes en los próximos 7 días.</p>
            }
          </ui-card>

          <ui-card heading="Últimos movimientos">
            <a card-actions class="small link" routerLink="/finanzas/movimientos">Ver todos</a>
            @if (data.recent_transactions.length > 0) {
              <div class="ui-list">
                @for (transaction of data.recent_transactions; track transaction.id) {
                  <fin-transaction-row [transaction]="transaction" (activate)="edit($event)" />
                }
              </div>
            } @else {
              <ui-empty-state icon="inbox" heading="Aún no hay movimientos">
                <button ui-button size="sm" variant="primary" icon="plus" type="button" (click)="create()">Añadir movimiento</button>
              </ui-empty-state>
            }
          </ui-card>
        </div>

        <ui-card class="section" heading="Patrimonio · 12 periodos">
          @if (history().labels.length > 1) {
            <ui-chart
              type="line"
              ariaLabel="Evolución del patrimonio"
              [labels]="history().labels"
              [series]="history().netWorth"
              [showLegend]="false"
            />
          } @else {
            <p class="small muted">La evolución aparecerá cuando tengas más de un periodo.</p>
          }
        </ui-card>
      }
    } @else if (resource.error()) {
      <ui-card>
        <ui-empty-state icon="circle-alert" heading="No se ha podido cargar el resumen" description="Comprueba tu conexión e inténtalo de nuevo.">
          <button ui-button type="button" variant="secondary" (click)="resource.reload()">Reintentar</button>
        </ui-empty-state>
      </ui-card>
    } @else {
      <div class="grid-cards g-4">
        @for (item of [1, 2, 3, 4]; track item) {
          <ui-card>
            <ui-skeleton width="50%" height="13px" />
            <ui-skeleton width="80%" height="28px" class="gap" />
          </ui-card>
        }
      </div>
      <div class="grid-cards g-main section">
        <ui-card><ui-skeleton height="240px" /></ui-card>
        <ui-card><ui-skeleton height="240px" /></ui-card>
      </div>
    }
  `,
  styles: `
    .section {
      margin-top: 16px;
    }
    .link {
      color: var(--text-2);
      text-decoration: none;
      white-space: nowrap;
    }
    .link:hover {
      color: var(--text);
      text-decoration: underline;
    }
    .budgets {
      gap: 14px;
    }
    .donut-host {
      container-type: inline-size;
    }
    .donut-wrap {
      display: grid;
      grid-template-columns: 160px minmax(0, 1fr);
      gap: 20px;
      align-items: center;
    }
    .donut {
      width: 160px;
    }
    .donut-legend {
      list-style: none;
      margin: 0;
      padding: 0;
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .donut-legend li {
      padding: 4px 0;
    }
    .legend-name {
      gap: 8px;
      min-width: 0;
      overflow: hidden;
      white-space: nowrap;
      text-overflow: ellipsis;
    }
    .legend-name .legend-swatch {
      margin-right: 0;
      flex: none;
    }
    .gap {
      margin-top: 8px;
    }
    @container (max-width: 380px) {
      .donut-wrap {
        grid-template-columns: minmax(0, 1fr);
        justify-items: center;
      }
      .donut-legend {
        width: 100%;
      }
    }
  `,
})
export class DashboardPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly accounts = inject(AccountsService);
  private readonly settings = inject(FinanceSettingsService);
  private readonly launcher = inject(TransactionSheetLauncher);
  protected readonly periods = inject(PeriodsService);

  private readonly queryParams = toSignal(this.route.queryParamMap, { initialValue: this.route.snapshot.queryParamMap });
  private readonly requestedPeriod = computed(() => this.queryParams().get('periodo'));
  protected readonly resource = inject(DashboardService).dashboardResource(this.requestedPeriod);
  protected readonly dashboard = computed<Dashboard | null>(() =>
    this.resource.hasValue() ? this.resource.value().data : null,
  );
  protected readonly selectedPeriodId = computed(() => this.dashboard()?.period.id ?? this.requestedPeriod());
  protected readonly noAccounts = computed(() => this.accounts.loaded() && this.accounts.all().length === 0);
  protected readonly warnAt = computed(() => (this.settings.settings()?.budget_warning_threshold ?? 80) / 100);
  protected readonly pastPeriodId = computed(() => {
    const period = this.dashboard()?.period;
    return period && !period.is_current ? period.id : null;
  });
  protected readonly periodQuery = computed(() => {
    const period = this.dashboard()?.period;
    return period && !period.is_current ? { periodo: period.id } : {};
  });

  protected readonly crumb = computed(() => {
    const period = this.dashboard()?.period;
    if (!period) {
      return 'Finanzas';
    }
    if (period.is_current) {
      return `Finanzas · ${period.name} · ${daysLeftLabel(period.days_remaining)}`;
    }
    return `Finanzas · ${period.name} (${period.range_label})`;
  });

  protected readonly netWorthDelta = computed(() => {
    const data = this.dashboard();
    if (!data || data.net_worth_delta_cents === null) {
      return null;
    }
    const previous = data.previous_period?.short_name;
    return `${formatMoney(data.net_worth_delta_cents, 'signed')}${previous ? ` vs ${previous}` : ''}`;
  });
  protected readonly savingsRate = computed(() => {
    const rate = this.dashboard()?.savings_rate_bp;
    return rate === null || rate === undefined ? 'Sin ingresos este periodo' : `Tasa de ahorro ${formatBasisPoints(rate)}`;
  });

  protected readonly history = computed(() => {
    const history = this.dashboard()?.history ?? [];
    return {
      labels: history.map((point) => point.label),
      flows: [
        { label: 'Ingresos', data: history.map((point) => point.income_cents), color: 1 as const },
        { label: 'Gastos', data: history.map((point) => point.expense_cents), color: 2 as const },
      ],
      netWorth: [{ label: 'Patrimonio', data: history.map((point) => point.net_worth_cents), color: 1 as const }],
    };
  });

  protected readonly donut = computed(() => buildDonut(this.dashboard()?.by_category ?? []));
  protected readonly donutLabels = computed(() => this.donut().map((slice) => slice.label));
  protected readonly donutSeries = computed(() => [{ label: 'Gasto', data: this.donut().map((slice) => slice.amount) }]);
  protected readonly donutColors = computed(() => this.donut().map((slice) => slice.color));
  protected readonly donutTotal = computed(() => formatMoneyCompact(this.donut().reduce((sum, slice) => sum + slice.amount, 0)));

  protected readonly deltaTone = deltaTone;
  protected readonly deltaIcon = deltaIcon;

  protected money(cents: number): string {
    return formatMoney(cents);
  }

  protected signed(cents: number): string {
    return formatMoney(cents, 'signed');
  }

  protected percentDelta(value: BasisPoints | null | undefined): string | null {
    const previous = this.dashboard()?.previous_period?.short_name;
    if (value === null || value === undefined || !previous) {
      return null;
    }
    return `${formatBasisPoints(value, true)} vs ${previous}`;
  }

  protected colorVar(color: UiChartColor): string {
    return typeof color === 'number' ? `--c${color}` : `--${color}`;
  }

  protected shortDate(value: string): string {
    return formatShortDate(value);
  }

  protected inDays(value: string): string {
    return inDaysLabel(daysBetween(todayIso(), value));
  }

  protected selectPeriod(id: string | null): void {
    const period = this.periods.find(id);
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { periodo: period && !period.is_current ? period.id : null },
      replaceUrl: true,
    });
  }

  protected edit(transaction: Transaction): void {
    void this.launcher.edit(transaction);
  }

  protected create(): void {
    void this.launcher.create();
  }
}
