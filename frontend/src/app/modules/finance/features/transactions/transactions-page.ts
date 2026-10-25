import { CdkMenu, CdkMenuItem, CdkMenuTrigger } from '@angular/cdk/menu';
import {
  afterNextRender,
  ChangeDetectionStrategy,
  Component,
  computed,
  DestroyRef,
  effect,
  ElementRef,
  inject,
  Injector,
  signal,
  untracked,
  viewChild,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { formatShortDate, todayIso } from '@shared/dates/dates';
import { RelativeDatePipe } from '@shared/dates/relative-date.pipe';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiChip } from '@ui/chip/chip';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSearch } from '@ui/search/search';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { AccountsService } from '../../data-access/accounts.service';
import { CategoriesService } from '../../data-access/categories.service';
import { FinanceChanges } from '../../data-access/finance-changes';
import {
  ACCOUNT_TYPE_ICONS,
  BulkUpdateInput,
  Transaction,
  TransactionKind,
  TransactionTotals,
} from '../../data-access/finance.models';
import { PeriodsService } from '../../data-access/periods.service';
import { TagsService } from '../../data-access/tags.service';
import {
  activeFilterCount,
  EMPTY_FILTERS,
  filtersFromParams,
  filtersToApiQuery,
  filtersToParams,
  TransactionFilters,
  UNCATEGORIZED,
} from '../../data-access/transaction-filters';
import { TransactionsService } from '../../data-access/transactions.service';
import { periodButtonLabel } from '../../ui/period-selector';
import { FinTransactionRow } from '../../ui/transaction-row';
import { BulkEditData, BulkEditDialog } from './bulk-edit-dialog';
import { FilterOption, FilterOptionsData, FilterOptionsDialog } from './filter-options-dialog';
import { MoreFilters, MoreFiltersDialog } from './more-filters-dialog';
import { EntryKind } from './transaction-form';
import { TransactionSheetLauncher } from './transaction-sheet.launcher';

const PAGE_SIZE = 50;

export interface DayGroup {
  date: string;
  total: number;
  items: Transaction[];
}

export function groupByDay(transactions: Transaction[], hideIncomingTransfers: boolean): DayGroup[] {
  const groups: DayGroup[] = [];
  for (const transaction of transactions) {
    if (hideIncomingTransfers && transaction.kind === 'transfer' && transaction.amount_cents > 0) {
      const outgoingVisible = transactions.some(
        (other) => other.transfer_group_id === transaction.transfer_group_id && other.id !== transaction.id,
      );
      if (outgoingVisible) {
        continue;
      }
    }
    let group = groups.at(-1);
    if (!group || group.date !== transaction.date) {
      group = { date: transaction.date, total: 0, items: [] };
      groups.push(group);
    }
    group.items.push(transaction);
    if (transaction.kind !== 'transfer') {
      group.total += transaction.amount_cents;
    }
  }
  return groups;
}

@Component({
  selector: 'app-finance-transactions-page',
  imports: [
    UiPageHeader,
    UiCard,
    UiButton,
    UiChip,
    UiIcon,
    UiSearch,
    UiSkeleton,
    UiEmptyState,
    FinTransactionRow,
    MoneyPipe,
    RelativeDatePipe,
    CdkMenuTrigger,
    CdkMenu,
    CdkMenuItem,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Movimientos" crumb="Finanzas">
      <button ui-button type="button" variant="secondary" size="sm" icon="download" class="d-only" (click)="exportCsv()">
        Exportar CSV
      </button>
      <button
        ui-button
        type="button"
        size="sm"
        [variant]="selecting() ? 'secondary' : 'ghost'"
        icon="list-checks"
        [attr.aria-pressed]="selecting()"
        (click)="toggleSelecting()"
      >
        <span class="d-only">{{ selecting() ? 'Terminar' : 'Seleccionar' }}</span>
      </button>
      <button ui-button type="button" variant="primary" size="sm" icon="plus" class="d-only" (click)="create()">Nuevo</button>
    </ui-page-header>

    <div class="stack page">
      <ui-search
        placeholder="Buscar por comercio, concepto o nota"
        ariaLabel="Buscar movimientos"
        [value]="searchText()"
        (valueChange)="onSearch($event)"
      />

      <div class="hscroll chips" role="toolbar" aria-label="Filtros">
        <button ui-chip type="button" icon="calendar" [selected]="true" [pressable]="false" [cdkMenuTriggerFor]="periodMenu">
          {{ periodChipLabel() }}
        </button>
        <button ui-chip type="button" icon="wallet" [selected]="filters().accountIds.length > 0" [pressable]="false" (click)="pickAccounts()">
          {{ accountChipLabel() }}
        </button>
        <button ui-chip type="button" icon="tag" [selected]="filters().categoryIds.length > 0" [pressable]="false" (click)="pickCategories()">
          {{ categoryChipLabel() }}
        </button>
        <button ui-chip type="button" icon="hash" [selected]="filters().tags.length > 0" [pressable]="false" (click)="pickTags()">
          {{ tagChipLabel() }}
        </button>
        <button ui-chip type="button" [selected]="filters().kinds.length > 0" [pressable]="false" (click)="pickKinds()">
          {{ kindChipLabel() }}
        </button>
        <button ui-chip type="button" icon="clock" [selected]="filters().status === 'pending'" (click)="togglePending()">
          Pendientes{{ pendingCount() !== null ? ' (' + pendingCount() + ')' : '' }}
        </button>
        <button ui-chip type="button" icon="circle-dashed" [selected]="filters().uncategorized" (click)="toggleUncategorized()">
          Sin categoría
        </button>
        <button ui-chip type="button" icon="sliders-horizontal" [selected]="moreFiltersActive()" [pressable]="false" (click)="pickMore()">
          Más filtros
        </button>
        @if (activeCount() > 0 || filters().q) {
          <button ui-chip type="button" icon="x" [pressable]="false" (click)="clearFilters()">Limpiar</button>
        }
      </div>

      <ng-template #periodMenu>
        <div class="ui-menu period-menu" cdkMenu aria-label="Periodo">
          @for (period of periods.all(); track period.id) {
            <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="setPeriod(period.is_current ? 'current' : period.id)">
              <span class="menu-text">
                <span>{{ period.name }}</span>
                <span class="small faint">{{ period.range_label }}</span>
              </span>
              @if (selectedPeriodId() === period.id) {
                <ui-icon name="check" [size]="16" />
              }
            </button>
          }
          <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="setPeriod('all')">
            <span class="menu-text">Todos los periodos</span>
            @if (filters().period === 'all' && !filters().from && !filters().to) {
              <ui-icon name="check" [size]="16" />
            }
          </button>
        </div>
      </ng-template>

      @if (selecting()) {
        <div class="selection-bar" role="region" aria-label="Selección">
          <span class="small">
            <b>{{ selected().size }}</b> {{ selected().size === 1 ? 'seleccionado' : 'seleccionados' }}
          </span>
          <span class="row actions">
            <button ui-button type="button" variant="ghost" size="sm" (click)="selectAllLoaded()">Todos</button>
            <button ui-button type="button" variant="primary" size="sm" icon="pencil" [disabled]="selected().size === 0" (click)="bulkEdit()">
              Editar
            </button>
          </span>
        </div>
      }

      <ui-card padding="sm">
        <div class="row wrap between small totals">
          @if (totals(); as summary) {
            <span class="muted">{{ countLabel(summary.count) }}</span>
            <span class="row sums">
              <span>Ingresos <b class="num pos">{{ summary.income_cents | money: 'signed' }}</b></span>
              <span>Gastos <b class="num">{{ summary.expense_cents | money: 'signed' }}</b></span>
            </span>
          } @else {
            <ui-skeleton width="120px" height="14px" />
            <ui-skeleton width="220px" height="14px" />
          }
        </div>
      </ui-card>

      @if (error()) {
        <ui-card>
          <ui-empty-state icon="circle-alert" heading="No se han podido cargar los movimientos" [description]="error()">
            <button ui-button type="button" variant="secondary" (click)="reload()">Reintentar</button>
          </ui-empty-state>
        </ui-card>
      } @else if (initialLoading()) {
        <ui-card padding="list">
          @for (row of skeletonRows; track row) {
            <div class="skeleton-row">
              <ui-skeleton width="36px" height="36px" radius="999px" />
              <div class="skeleton-body">
                <ui-skeleton width="45%" height="14px" />
                <ui-skeleton width="30%" height="12px" />
              </div>
              <ui-skeleton width="70px" height="14px" />
            </div>
          }
        </ui-card>
      } @else if (groups().length === 0) {
        <ui-card>
          @if (onlyUncategorized()) {
            <ui-empty-state icon="circle-check" heading="Todo categorizado" description="No quedan movimientos sin categoría en lo que estás viendo.">
              <button ui-button type="button" variant="secondary" (click)="toggleUncategorized()">Ver todos los movimientos</button>
            </ui-empty-state>
          } @else if (activeCount() > 0 || filters().q) {
            <ui-empty-state icon="search" heading="Nada coincide con los filtros" description="Prueba con otro periodo o quita algún filtro.">
              <button ui-button type="button" variant="secondary" (click)="clearFilters()">Quitar filtros</button>
            </ui-empty-state>
          } @else {
            <ui-empty-state icon="inbox" heading="Aún no hay movimientos" description="Apunta tu primer gasto y empezarás a ver tu resumen.">
              <button ui-button type="button" variant="primary" icon="plus" (click)="create()">Añadir movimiento</button>
            </ui-empty-state>
          }
        </ui-card>
      } @else {
        <ui-card padding="none" class="list-card">
          @for (group of groups(); track group.date) {
            <div class="day-head">
              <span>{{ group.date | relativeDate: 'title' }}</span>
              <span class="num">{{ group.total | money: 'signed' }}</span>
            </div>
            <div class="ui-list">
              @for (transaction of group.items; track transaction.id) {
                <fin-transaction-row
                  [transaction]="transaction"
                  [selectable]="selecting()"
                  [selected]="selected().has(transaction.id)"
                  (activate)="onActivate($event)"
                />
              }
            </div>
          }
          <div #sentinel class="sentinel" aria-hidden="true"></div>
          @if (hasMore()) {
            <div class="more">
              <button ui-button type="button" variant="ghost" size="sm" [loading]="loadingMore()" (click)="loadMore()">Cargar más</button>
            </div>
          }
        </ui-card>
      }
    </div>
  `,
  styles: `
    .page {
      gap: 12px;
    }
    .chips {
      margin: 0 -2px;
      padding: 2px;
    }
    .period-menu {
      max-height: 360px;
      overflow: auto;
      min-width: 260px;
    }
    .period-menu .ui-menu-item {
      min-height: 48px;
    }
    .menu-text {
      display: flex;
      flex-direction: column;
      flex: 1;
    }
    .totals {
      gap: 8px;
    }
    .sums {
      gap: 16px;
    }
    .list-card {
      padding: 4px 16px 8px;
    }
    .selection-bar {
      position: sticky;
      top: 64px;
      z-index: 4;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 8px 8px 8px 16px;
      background: var(--primary-soft);
      border-radius: var(--r-full);
    }
    .actions {
      gap: 4px;
    }
    .skeleton-row {
      display: flex;
      align-items: center;
      gap: 12px;
      min-height: 56px;
      padding: 10px 4px;
    }
    .skeleton-body {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .sentinel {
      height: 1px;
    }
    .more {
      display: flex;
      justify-content: center;
      padding: 8px 0;
    }
  `,
})
export class TransactionsPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly service = inject(TransactionsService);
  private readonly accounts = inject(AccountsService);
  private readonly categories = inject(CategoriesService);
  private readonly tags = inject(TagsService);
  private readonly changes = inject(FinanceChanges);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);
  private readonly launcher = inject(TransactionSheetLauncher);
  protected readonly periods = inject(PeriodsService);
  private readonly sentinel = viewChild<ElementRef<HTMLElement>>('sentinel');
  private readonly injector = inject(Injector);

  protected readonly skeletonRows = [1, 2, 3, 4, 5, 6];
  private readonly queryParams = toSignal(this.route.queryParams, { initialValue: this.route.snapshot.queryParams });
  private readonly quickAdd = this.route.snapshot.data['quickAdd'] === true;
  protected readonly filters = computed<TransactionFilters>(() =>
    this.quickAdd ? EMPTY_FILTERS : filtersFromParams(this.queryParams()),
  );
  protected readonly searchText = signal(this.filters().q);

  protected readonly items = signal<Transaction[]>([]);
  protected readonly totals = signal<TransactionTotals | null>(null);
  protected readonly cursor = signal<string | null>(null);
  protected readonly hasMore = signal(false);
  protected readonly initialLoading = signal(true);
  protected readonly loadingMore = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly pendingCount = signal<number | null>(null);
  protected readonly selecting = signal(false);
  protected readonly selected = signal<ReadonlySet<string>>(new Set());

  protected readonly activeCount = computed(() => activeFilterCount(this.filters()));
  protected readonly onlyUncategorized = computed(() => this.filters().uncategorized && this.activeCount() === 1 && !this.filters().q);
  protected readonly moreFiltersActive = computed(() => {
    const filters = this.filters();
    return filters.min !== null || filters.max !== null || filters.from !== null || filters.to !== null || filters.status === 'cleared';
  });
  protected readonly selectedPeriodId = computed(() => {
    const period = this.filters().period;
    if (period === 'all') {
      return null;
    }
    return period === 'current' ? (this.periods.current()?.id ?? null) : period;
  });
  private readonly apiQuery = computed(() => {
    const filters = this.filters();
    if (filters.period === 'current' && !filters.from && !filters.to && !this.periods.loaded()) {
      return null;
    }
    return filtersToApiQuery(filters, this.periods.current()?.id ?? null);
  });
  protected readonly groups = computed(() => groupByDay(this.items(), this.filters().accountIds.length === 0));

  protected readonly periodChipLabel = computed(() => {
    const filters = this.filters();
    if (filters.from || filters.to) {
      const from = filters.from ? formatShortDate(filters.from, true) : '…';
      const to = filters.to ? formatShortDate(filters.to, true) : 'hoy';
      return `${from} – ${to}`;
    }
    if (filters.period === 'all') {
      return 'Todos los periodos';
    }
    const period = this.periods.find(this.selectedPeriodId());
    return period ? periodButtonLabel(period) : 'Periodo actual';
  });
  protected readonly accountChipLabel = computed(() => {
    const ids = this.filters().accountIds;
    if (ids.length === 0) {
      return 'Todas las cuentas';
    }
    return ids.length === 1 ? (this.accounts.find(ids[0])?.name ?? '1 cuenta') : `${ids.length} cuentas`;
  });
  protected readonly categoryChipLabel = computed(() => {
    const ids = this.filters().categoryIds;
    if (ids.length === 0) {
      return 'Categoría';
    }
    if (ids.length === 1) {
      return ids[0] === UNCATEGORIZED ? 'Sin categoría' : (this.categories.find(ids[0])?.category.name ?? '1 categoría');
    }
    return `${ids.length} categorías`;
  });
  protected readonly tagChipLabel = computed(() => {
    const tags = this.filters().tags;
    return tags.length === 0 ? 'Etiqueta' : tags.length === 1 ? `#${tags[0]}` : `${tags.length} etiquetas`;
  });
  protected readonly kindChipLabel = computed(() => {
    const kinds = this.filters().kinds;
    if (kinds.length === 0) {
      return 'Gastos e ingresos';
    }
    return kinds.map((kind) => KIND_PLURAL[kind]).join(' y ');
  });

  private requestId = 0;
  private searchTimer: ReturnType<typeof setTimeout> | null = null;

  constructor() {
    effect(() => {
      const query = this.apiQuery();
      this.changes.version('transactions')();
      if (query === null) {
        return;
      }
      untracked(() => this.loadFirstPage());
    });

    effect(() => {
      const q = this.filters().q;
      untracked(() => {
        if (this.searchText().trim() !== q) {
          this.searchText.set(q);
        }
      });
    });

    const destroyRef = inject(DestroyRef);
    afterNextRender(() => {
      if (typeof IntersectionObserver === 'undefined') {
        return;
      }
      const observer = new IntersectionObserver((entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          this.loadMore();
        }
      });
      const observed = effect(
        () => {
          observer.disconnect();
          const element = this.sentinel()?.nativeElement;
          if (element) {
            observer.observe(element);
          }
        },
        { injector: this.injector },
      );
      destroyRef.onDestroy(() => {
        observed.destroy();
        observer.disconnect();
      });
    });

    if (this.quickAdd) {
      afterNextRender(() => this.openQuickAdd());
    }
  }

  protected countLabel(count: number): string {
    return count === 1 ? '1 movimiento' : `${count} movimientos`;
  }

  protected reload(): void {
    this.loadFirstPage();
  }

  protected onSearch(text: string): void {
    this.searchText.set(text);
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => this.updateFilters({ q: text.trim() }), 300);
  }

  protected setPeriod(period: TransactionFilters['period']): void {
    this.updateFilters({ period, from: null, to: null });
  }

  protected togglePending(): void {
    this.updateFilters({ status: this.filters().status === 'pending' ? null : 'pending' });
  }

  protected toggleUncategorized(): void {
    this.updateFilters({ uncategorized: !this.filters().uncategorized });
  }

  protected clearFilters(): void {
    this.searchText.set('');
    this.navigate({ ...EMPTY_FILTERS, period: this.filters().period });
  }

  protected async pickAccounts(): Promise<void> {
    const options: FilterOption[] = this.accounts.all().map((account) => ({
      value: account.id,
      label: account.name,
      icon: account.icon ?? ACCOUNT_TYPE_ICONS[account.type],
      description: account.archived ? 'Archivada' : null,
    }));
    const result = await this.pick({ title: 'Cuentas', options, selected: this.filters().accountIds });
    if (result) {
      this.updateFilters({ accountIds: result });
    }
  }

  protected async pickCategories(): Promise<void> {
    const options: FilterOption[] = [
      { value: UNCATEGORIZED, label: 'Sin categoría', icon: 'circle-dashed' },
      ...this.categories.entries().map((entry) => ({
        value: entry.category.id,
        label: entry.category.name,
        icon: entry.icon,
        indent: entry.parent !== null,
        description: entry.parent === null && entry.category.kind === 'income' ? 'Ingreso' : null,
      })),
    ];
    const result = await this.pick({ title: 'Categorías', options, selected: this.filters().categoryIds, searchable: true });
    if (result) {
      this.updateFilters({ categoryIds: result });
    }
  }

  protected async pickTags(): Promise<void> {
    const options: FilterOption[] = this.tags.all().map((tag) => ({
      value: tag.name,
      label: `#${tag.name}`,
      description: tag.transactions_count === 1 ? '1 movimiento' : `${tag.transactions_count} movimientos`,
    }));
    const result = await this.pick({
      title: 'Etiquetas',
      options,
      selected: this.filters().tags,
      searchable: options.length > 8,
      emptyText: 'Aún no has usado etiquetas.',
    });
    if (result) {
      this.updateFilters({ tags: result });
    }
  }

  protected async pickKinds(): Promise<void> {
    const options: FilterOption[] = (['expense', 'income', 'transfer', 'adjustment'] as TransactionKind[]).map((kind) => ({
      value: kind,
      label: KIND_PLURAL[kind],
    }));
    const result = await this.pick({ title: 'Tipo de movimiento', options, selected: this.filters().kinds });
    if (result) {
      this.updateFilters({ kinds: result as TransactionKind[] });
    }
  }

  protected async pickMore(): Promise<void> {
    const filters = this.filters();
    const ref = this.dialogs.open<MoreFiltersDialog, MoreFilters, MoreFilters>(MoreFiltersDialog, {
      data: { min: filters.min, max: filters.max, from: filters.from, to: filters.to, status: filters.status },
    });
    const result = await firstValueFrom(ref.closed);
    if (result) {
      this.updateFilters(result.from || result.to ? { ...result, period: 'all' } : result);
    }
  }

  protected toggleSelecting(): void {
    this.selecting.update((value) => !value);
    this.selected.set(new Set());
  }

  protected selectAllLoaded(): void {
    const all = this.groups().flatMap((group) => group.items.map((item) => item.id));
    this.selected.set(this.selected().size === all.length ? new Set() : new Set(all));
  }

  protected onActivate(transaction: Transaction): void {
    if (this.selecting()) {
      const next = new Set(this.selected());
      if (next.has(transaction.id)) {
        next.delete(transaction.id);
      } else {
        next.add(transaction.id);
      }
      this.selected.set(next);
      return;
    }
    void this.launcher.edit(transaction);
  }

  protected async bulkEdit(): Promise<void> {
    const ids = [...this.selected()];
    if (ids.length === 0) {
      return;
    }
    const ref = this.dialogs.open<BulkEditDialog, BulkEditData, Omit<BulkUpdateInput, 'ids'>>(BulkEditDialog, {
      data: { count: ids.length },
    });
    const changes = await firstValueFrom(ref.closed);
    if (!changes) {
      return;
    }
    try {
      const updated = await this.service.bulkUpdate({ ids, ...changes });
      this.toast.show(updated === 1 ? '1 movimiento actualizado' : `${updated} movimientos actualizados`);
      this.selecting.set(false);
      this.selected.set(new Set());
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se han podido actualizar los movimientos.'));
    }
  }

  protected create(): void {
    const accountId = this.filters().accountIds.length === 1 ? this.filters().accountIds[0] : null;
    void this.launcher.create(accountId ? { accountId } : {});
  }

  protected exportCsv(): void {
    const query = this.apiQuery();
    if (query === null) {
      return;
    }
    const link = document.createElement('a');
    link.href = this.service.exportUrl(query);
    link.download = `movimientos-${todayIso()}.csv`;
    link.rel = 'noopener';
    document.body.appendChild(link);
    link.click();
    link.remove();
  }

  protected async loadMore(): Promise<void> {
    const query = this.apiQuery();
    const cursor = this.cursor();
    if (!query || !cursor || !this.hasMore() || this.loadingMore() || this.initialLoading()) {
      return;
    }
    const id = this.requestId;
    this.loadingMore.set(true);
    try {
      const page = await this.service.list(query, cursor, PAGE_SIZE);
      if (id !== this.requestId) {
        return;
      }
      this.items.update((items) => [...items, ...page.data.filter((item) => !items.some((existing) => existing.id === item.id))]);
      this.cursor.set(page.meta.next_cursor);
      this.hasMore.set(page.meta.has_more);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se han podido cargar más movimientos.'));
    } finally {
      this.loadingMore.set(false);
    }
  }

  private async loadFirstPage(): Promise<void> {
    const query = this.apiQuery();
    if (query === null) {
      return;
    }
    const id = ++this.requestId;
    this.error.set(null);
    if (this.items().length === 0) {
      this.initialLoading.set(true);
    }
    try {
      const [page, pending] = await Promise.all([
        this.service.list(query, null, PAGE_SIZE),
        this.service.list({ ...query, status: 'pending' }, null, 1).catch(() => null),
      ]);
      if (id !== this.requestId) {
        return;
      }
      this.items.set(page.data);
      this.totals.set(page.meta.totals);
      this.cursor.set(page.meta.next_cursor);
      this.hasMore.set(page.meta.has_more);
      this.pendingCount.set(pending?.meta.totals.count ?? null);
      const visible = new Set(page.data.map((item) => item.id));
      this.selected.update((current) => new Set([...current].filter((item) => visible.has(item))));
    } catch (error) {
      if (id === this.requestId) {
        this.error.set(firstValidationMessage(error, 'Comprueba tu conexión e inténtalo de nuevo.'));
      }
    } finally {
      if (id === this.requestId) {
        this.initialLoading.set(false);
      }
    }
  }

  private async pick(data: FilterOptionsData): Promise<string[] | undefined> {
    const ref = this.dialogs.open<FilterOptionsDialog, FilterOptionsData, string[]>(FilterOptionsDialog, { data });
    return firstValueFrom(ref.closed);
  }

  private updateFilters(patch: Partial<TransactionFilters>): void {
    this.navigate({ ...this.filters(), ...patch });
  }

  private navigate(filters: TransactionFilters): void {
    void this.router.navigate([], { relativeTo: this.route, queryParams: filtersToParams(filters), replaceUrl: true });
  }

  private async openQuickAdd(): Promise<void> {
    const tipo = this.route.snapshot.queryParamMap.get('tipo');
    const kind: Exclude<EntryKind, 'adjustment'> = tipo === 'ingreso' ? 'income' : tipo === 'transferencia' ? 'transfer' : 'expense';
    const accountId = this.route.snapshot.queryParamMap.get('cuenta');
    await this.launcher.create({ kind, accountId });
    void this.router.navigate(['/finanzas/movimientos'], { replaceUrl: true });
  }
}

const KIND_PLURAL: Record<TransactionKind, string> = {
  expense: 'Gastos',
  income: 'Ingresos',
  transfer: 'Transferencias',
  adjustment: 'Ajustes',
};
