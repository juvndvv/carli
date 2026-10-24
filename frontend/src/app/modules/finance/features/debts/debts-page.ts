import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { contactBalanceLabel } from '@finance/data-access/contacts.models';
import { ContactsService } from '@finance/data-access/contacts.service';
import { Debt, DEBT_DIRECTION_LABELS, debtInstallmentsLabel } from '@finance/data-access/debts.models';
import { DebtsService } from '@finance/data-access/debts.service';
import { formatShortDate } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiAvatar } from '@ui/avatar/avatar';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiProgress } from '@ui/progress/progress';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { DebtDetailDialog, DebtDetailDialogData } from './debt-detail-dialog';
import { DebtDialog, DebtDialogData } from './debt-dialog';

@Component({
  selector: 'app-finance-debts-page',
  imports: [
    UiPageHeader,
    UiCard,
    UiEmptyState,
    UiButton,
    UiStat,
    UiBadge,
    UiProgress,
    UiListItem,
    UiAvatar,
    UiSkeleton,
    MoneyPipe,
    RouterLink,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Deudas" crumb="Finanzas">
      <button ui-button variant="primary" size="sm" icon="plus" aria-label="Nueva deuda" (click)="create()">
        <span class="d-only">Nueva deuda</span>
      </button>
    </ui-page-header>

    <div class="grid-cards g-2 stats">
      <ui-stat label="Te deben" icon="arrow-down-left" tone="positive" [value]="owedToMeLabel()" [delta]="owedToMeDelta()" />
      <ui-stat label="Debes" icon="arrow-up-right" [value]="iOweLabel()" [delta]="iOweDelta()" />
    </div>

    <div class="grid-cards g-2 block">
      <ui-card heading="Préstamos y deudas">
        @if (debts.loading() && !debts.loaded()) {
          <div class="stack" aria-busy="true">
            <ui-skeleton width="50%" />
            <ui-skeleton height="8px" radius="999px" />
            <ui-skeleton width="40%" />
            <ui-skeleton height="8px" radius="999px" />
          </div>
        } @else if (debts.error() && !debts.loaded()) {
          <ui-empty-state icon="circle-alert" heading="No se han podido cargar" [description]="debts.error()">
            <button ui-button size="sm" icon="refresh-cw" (click)="debts.load()">Reintentar</button>
          </ui-empty-state>
        } @else if (debts.openDebts().length === 0) {
          <ui-empty-state
            icon="hand-coins"
            heading="Sin deudas pendientes"
            description="Apunta préstamos y dinero que debes o te deben, y lleva la cuenta de cada pago."
          >
            <button ui-button variant="primary" size="sm" icon="plus" (click)="create()">Nueva deuda</button>
          </ui-empty-state>
        } @else {
          <div class="debts">
            @for (debt of debts.openDebts(); track debt.id) {
              <button type="button" class="debt" (click)="open(debt)">
                <span class="row between top">
                  <span class="titles">
                    <span class="debt-name">{{ debt.name }}</span>
                    <span class="small faint">{{ debtSubtitle(debt) }}</span>
                  </span>
                  <ui-badge [tone]="debt.direction === 'i_owe' ? 'neutral' : 'positive'">{{ directionLabel(debt) }}</ui-badge>
                </span>
                <span class="row between small figures">
                  <span class="muted">Pendiente <b class="num strong">{{ debt.pending_cents | money }}</b> de {{ debt.principal_cents | money }}</span>
                  @if (nextDate(debt); as next) {
                    <span class="faint nowrap">{{ next }}</span>
                  }
                </span>
                <ui-progress tone="primary" [ratio]="debt.progress_bp / 10000" [label]="'Pagado de ' + debt.name" />
              </button>
            }
          </div>
        }
        @if (debts.closedDebts().length) {
          <div class="closed">
            <button ui-button type="button" variant="ghost" size="sm" [trailingIcon]="showClosed() ? 'chevron-up' : 'chevron-down'" (click)="showClosed.set(!showClosed())">
              Saldadas ({{ debts.closedDebts().length }})
            </button>
            @if (showClosed()) {
              <div class="ui-list">
                @for (debt of debts.closedDebts(); track debt.id) {
                  <button
                    ui-list-item
                    type="button"
                    [heading]="debt.name"
                    [subtitle]="debtSubtitle(debt)"
                    icon="check"
                    iconSoft
                    [value]="debt.principal_cents | money"
                    valueTone="muted"
                    (click)="open(debt)"
                  ></button>
                }
              </div>
            }
          </div>
        }
      </ui-card>

      <ui-card heading="Gastos compartidos" padding="list">
        <a card-actions ui-button variant="ghost" size="sm" trailingIcon="chevron-right" routerLink="/finanzas/compartidos">Ver todo</a>
        @if (contacts.contacts().length === 0 && contacts.loaded()) {
          <ui-empty-state icon="users" heading="Nadie con saldo" description="Reparte un gasto con un contacto y verás aquí quién te debe.">
            <a ui-button size="sm" icon="user-plus" routerLink="/finanzas/compartidos">Contactos</a>
          </ui-empty-state>
        } @else {
          <div class="ui-list">
            @for (contact of topContacts(); track contact.id) {
              <a ui-list-item [heading]="contact.name" [routerLink]="['/finanzas/compartidos', contact.id]">
                <ui-avatar leading [name]="contact.name" />
                <span trailing class="num value" [class.pos]="contact.balance_cents > 0" [class.muted]="contact.balance_cents === 0">
                  {{ balanceLabel(contact.balance_cents) }}
                </span>
              </a>
            }
          </div>
        }
      </ui-card>
    </div>
  `,
  styles: `
    .stats {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
    .block {
      margin-top: 16px;
      align-items: start;
    }
    .debts {
      display: flex;
      flex-direction: column;
    }
    .debt {
      display: flex;
      flex-direction: column;
      gap: 0;
      width: 100%;
      text-align: left;
      background: none;
      border: 0;
      border-bottom: 1px solid var(--border);
      padding: 14px 4px;
      color: inherit;
      font: inherit;
      cursor: pointer;
      border-radius: var(--r-md);
      transition: background var(--motion-fast);
    }
    .debt:first-child {
      padding-top: 0;
    }
    .debt:last-child {
      border-bottom: 0;
    }
    .debt:hover {
      background: var(--surface-2);
    }
    .top {
      align-items: flex-start;
    }
    .titles {
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .debt-name {
      font-weight: 600;
    }
    .figures {
      margin: 10px 0 6px;
    }
    .nowrap {
      white-space: nowrap;
    }
    .strong {
      color: var(--text);
    }
    .value {
      font-weight: 550;
      white-space: nowrap;
    }
    .closed {
      margin-top: 12px;
      display: flex;
      flex-direction: column;
      gap: 4px;
      align-items: flex-start;
    }
    .closed .ui-list {
      width: 100%;
    }
  `,
})
export class DebtsPage implements OnInit {
  protected readonly debts = inject(DebtsService);
  protected readonly contacts = inject(ContactsService);
  private readonly dialogs = inject(DialogService);

  protected readonly showClosed = signal(false);

  protected readonly owedToMeLabel = computed(() => formatMoney(this.debts.meta().owed_to_me_cents));
  protected readonly iOweLabel = computed(() => formatMoney(this.debts.meta().i_owe_cents));
  protected readonly owedToMeDelta = computed(() => countLabel(this.debts.owedToMe().length));
  protected readonly iOweDelta = computed(() => countLabel(this.debts.iOwe().length));
  protected readonly topContacts = computed(() =>
    [...this.contacts.contacts()]
      .filter((contact) => contact.balance_cents !== 0)
      .sort((a, b) => Math.abs(b.balance_cents) - Math.abs(a.balance_cents))
      .slice(0, 5),
  );

  ngOnInit(): void {
    void this.debts.load();
    void this.contacts.load();
  }

  protected directionLabel(debt: Debt): string {
    return DEBT_DIRECTION_LABELS[debt.direction];
  }

  protected debtSubtitle(debt: Debt): string {
    return [debt.contact?.name, debtInstallmentsLabel(debt, (cents) => formatMoney(cents))].filter(Boolean).join(' · ');
  }

  protected nextDate(debt: Debt): string | null {
    if (debt.next_payment_date) {
      return `Próx. ${formatShortDate(debt.next_payment_date)}`;
    }
    return debt.due_date ? `Vence ${formatShortDate(debt.due_date)}` : null;
  }

  protected balanceLabel(cents: number): string {
    return contactBalanceLabel(cents, (value) => formatMoney(value));
  }

  protected create(): void {
    this.dialogs.open<DebtDialog, DebtDialogData>(DebtDialog, { data: { debt: null } });
  }

  protected open(debt: Debt): void {
    this.dialogs.open<DebtDetailDialog, DebtDetailDialogData>(DebtDetailDialog, { data: { debt }, size: 'lg' });
  }
}

function countLabel(count: number): string {
  if (count === 0) {
    return 'Nada pendiente';
  }
  return count === 1 ? '1 deuda abierta' : `${count} deudas abiertas`;
}
