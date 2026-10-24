import { ChangeDetectionStrategy, Component, computed, effect, inject, input, signal, untracked } from '@angular/core';
import { RouterLink } from '@angular/router';
import { addDays, formatShortDate, IsoDate, todayIso } from '@shared/dates/dates';
import { RelativeDatePipe } from '@shared/dates/relative-date.pipe';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiChart } from '@ui/chart/chart';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiProgress } from '@ui/progress/progress';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { AccountsService } from '../../data-access/accounts.service';
import { FinanceChanges } from '../../data-access/finance-changes';
import { Account, ACCOUNT_TYPE_LABELS, Transaction } from '../../data-access/finance.models';
import { TransactionsService } from '../../data-access/transactions.service';
import { FinTransactionRow } from '../../ui/transaction-row';
import { groupByDay } from '../transactions/transactions-page';
import { TransactionSheetLauncher } from '../transactions/transaction-sheet.launcher';
import { AccountActions } from './account-actions';
import { cardSchedule } from './accounts-page';

const HISTORY_DAYS = 90;
const MAX_PAGES = 5;

export interface BalancePoint {
  date: IsoDate;
  balance: number;
}

export function balanceHistory(currentBalance: number, transactions: Transaction[], today: IsoDate, days: number): BalancePoint[] {
  const byDate = new Map<IsoDate, number>();
  for (const transaction of transactions) {
    byDate.set(transaction.date, (byDate.get(transaction.date) ?? 0) + transaction.amount_cents);
  }
  const future = [...byDate.entries()].filter(([date]) => date > today).reduce((sum, [, amount]) => sum + amount, 0);
  let balance = currentBalance - future;
  const points: BalancePoint[] = [];
  for (let offset = 0; offset < days; offset++) {
    const date = addDays(today, -offset);
    points.push({ date, balance });
    balance -= byDate.get(date) ?? 0;
  }
  return points.reverse();
}

@Component({
  selector: 'app-finance-account-detail-page',
  imports: [
    RouterLink,
    UiPageHeader,
    UiCard,
    UiStat,
    UiChart,
    UiButton,
    UiSkeleton,
    UiEmptyState,
    UiProgress,
    FinTransactionRow,
    MoneyPipe,
    RelativeDatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header [heading]="account()?.name ?? 'Cuenta'" crumb="Finanzas · Cuentas" backLink="/finanzas/cuentas">
      @if (account(); as current) {
        <button ui-button type="button" variant="ghost" size="sm" icon="pencil" (click)="actions.edit(current)">
          <span class="d-only">Editar</span>
        </button>
        <button ui-button type="button" variant="secondary" size="sm" icon="check-check" (click)="actions.reconcile(current)">
          <span class="d-only">Conciliar</span>
        </button>
        <button ui-button type="button" variant="primary" size="sm" icon="plus" class="d-only" (click)="create(current)">Nuevo</button>
      }
    </ui-page-header>

    @if (account(); as current) {
      <div class="grid-cards g-3">
        <ui-stat label="Saldo actual" [icon]="current.type === 'credit_card' ? 'credit-card' : 'wallet'" [value]="money(current.balance_cents)" [delta]="typeLabel(current)" />
        @if (current.type === 'credit_card' && current.credit_limit_cents) {
          <ui-card>
            <div class="small muted">Crédito</div>
            <div class="row between credit-head">
              <span class="small">Dispuesto <b class="num">{{ current.used_credit_cents ?? 0 | money }}</b></span>
              <span class="small">Disponible <b class="num">{{ current.available_credit_cents ?? 0 | money }}</b></span>
            </div>
            <ui-progress tone="primary" [value]="current.used_credit_cents ?? 0" [max]="current.credit_limit_cents" label="Crédito dispuesto" />
            <div class="small faint credit-foot">Límite {{ current.credit_limit_cents | money }}{{ schedule(current) ? ' · ' + schedule(current) : '' }}</div>
          </ui-card>
        } @else {
          <ui-stat label="Confirmado" icon="circle-check" [value]="money(current.cleared_balance_cents)" [delta]="current.pending_cents === 0 ? 'Todo confirmado' : 'Sin contar pendientes'" />
        }
        <ui-stat
          label="Pendiente"
          icon="clock"
          [tone]="current.pending_cents === 0 ? 'muted' : 'warning'"
          [value]="signed(current.pending_cents)"
          [delta]="current.include_in_net_worth ? 'Suma al patrimonio' : 'Fuera del patrimonio'"
        />
      </div>

      <ui-card class="section" heading="Evolución del saldo · 90 días">
        @if (loading()) {
          <ui-skeleton height="220px" />
        } @else {
          <ui-chart
            type="line"
            ariaLabel="Evolución del saldo en los últimos 90 días"
            categoryHeader="Día"
            [labels]="historyLabels()"
            [series]="historySeries()"
            [showLegend]="false"
          />
        }
      </ui-card>

      <ui-card class="section" padding="none">
        <div class="list-card">
          <div class="row between list-head">
            <h2>Movimientos recientes</h2>
            <a class="small link" routerLink="/finanzas/movimientos" [queryParams]="{ cuenta: current.id, periodo: 'todos' }">Ver todos</a>
          </div>
          @if (loading()) {
            <ui-skeleton height="56px" />
            <ui-skeleton height="56px" class="gap" />
          } @else if (groups().length === 0) {
            <ui-empty-state icon="inbox" heading="Sin movimientos" description="Los movimientos de esta cuenta aparecerán aquí.">
              <button ui-button type="button" variant="primary" icon="plus" (click)="create(current)">Añadir movimiento</button>
            </ui-empty-state>
          } @else {
            @for (group of groups(); track group.date) {
              <div class="day-head">
                <span>{{ group.date | relativeDate: 'title' }}</span>
                <span class="num">{{ group.total | money: 'signed' }}</span>
              </div>
              <div class="ui-list">
                @for (transaction of group.items; track transaction.id) {
                  <fin-transaction-row [transaction]="transaction" [showAccount]="false" (activate)="edit($event)" />
                }
              </div>
            }
          }
        </div>
      </ui-card>
    } @else if (missing()) {
      <ui-card>
        <ui-empty-state icon="landmark" heading="No encontramos esta cuenta" description="Puede que se haya eliminado.">
          <a ui-button variant="secondary" routerLink="/finanzas/cuentas">Volver a cuentas</a>
        </ui-empty-state>
      </ui-card>
    } @else {
      <div class="grid-cards g-3">
        <ui-card><ui-skeleton height="64px" /></ui-card>
        <ui-card><ui-skeleton height="64px" /></ui-card>
        <ui-card><ui-skeleton height="64px" /></ui-card>
      </div>
    }
  `,
  styles: `
    .section {
      margin-top: 16px;
    }
    .credit-head {
      margin: 8px 0;
    }
    .credit-foot {
      margin-top: 6px;
    }
    .list-card {
      padding: 16px 16px 8px;
    }
    .list-head {
      margin-bottom: 4px;
    }
    .link {
      color: var(--text-2);
    }
    .gap {
      margin-top: 8px;
    }
  `,
})
export class AccountDetailPage {
  private readonly accounts = inject(AccountsService);
  private readonly transactions = inject(TransactionsService);
  private readonly changes = inject(FinanceChanges);
  private readonly launcher = inject(TransactionSheetLauncher);
  protected readonly actions = inject(AccountActions);

  readonly id = input.required<string>();

  private readonly fetched = signal<Account | null>(null);
  protected readonly missing = signal(false);
  protected readonly loading = signal(true);
  private readonly items = signal<Transaction[]>([]);

  protected readonly account = computed(() => this.accounts.find(this.id()) ?? this.fetched());
  protected readonly groups = computed(() => groupByDay(this.items().slice(0, 50), false));
  private readonly history = computed(() => {
    const account = this.account();
    return account ? balanceHistory(account.balance_cents, this.items(), todayIso(), HISTORY_DAYS) : [];
  });
  protected readonly historyLabels = computed(() => this.history().map((point) => formatShortDate(point.date)));
  protected readonly historySeries = computed(() => [
    { label: 'Saldo', data: this.history().map((point) => point.balance), color: 1 as const },
  ]);

  constructor() {
    effect(() => {
      const id = this.id();
      const loaded = this.accounts.loaded();
      untracked(() => {
        if (loaded && !this.accounts.find(id)) {
          this.accounts
            .get(id)
            .then((account) => this.fetched.set(account))
            .catch(() => this.missing.set(true));
        }
      });
    });
    effect(() => {
      const id = this.id();
      this.changes.version('transactions')();
      untracked(() => this.loadTransactions(id));
    });
  }

  protected money(cents: number): string {
    return formatMoney(cents);
  }

  protected signed(cents: number): string {
    return formatMoney(cents, 'signed');
  }

  protected typeLabel(account: Account): string {
    return ACCOUNT_TYPE_LABELS[account.type];
  }

  protected schedule(account: Account): string | null {
    return cardSchedule(account);
  }

  protected edit(transaction: Transaction): void {
    void this.launcher.edit(transaction);
  }

  protected create(account: Account): void {
    void this.launcher.create({ accountId: account.id });
  }

  private async loadTransactions(id: string): Promise<void> {
    this.loading.set(this.items().length === 0);
    const from = addDays(todayIso(), -HISTORY_DAYS);
    const collected: Transaction[] = [];
    let cursor: string | null = null;
    try {
      for (let page = 0; page < MAX_PAGES; page++) {
        const result = await this.transactions.list({ account_id: [id], from }, cursor, 200);
        collected.push(...result.data);
        cursor = result.meta.next_cursor;
        if (!result.meta.has_more || !cursor) {
          break;
        }
      }
      if (id === this.id()) {
        this.items.set(collected);
      }
    } catch {
      this.items.set([]);
    } finally {
      this.loading.set(false);
    }
  }
}
