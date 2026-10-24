import { ChangeDetectionStrategy, Component, computed, inject, input, resource } from '@angular/core';
import { RouterLink } from '@angular/router';
import {
  ContactShare,
  contactBalanceLabel,
  FinanceContactDetail,
  shareTitle,
} from '@finance/data-access/contacts.models';
import { ContactsService } from '@finance/data-access/contacts.service';
import { DEBT_DIRECTION_LABELS, Debt } from '@finance/data-access/debts.models';
import { formatRelativeDay, formatShortDate } from '@shared/dates/dates';
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
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { firstValueFrom } from 'rxjs';
import { ContactDialog, ContactDialogData, ContactDialogResult } from './contact-dialog';
import { SettleDialog, SettleDialogData } from './settle-dialog';

@Component({
  selector: 'app-finance-contact-detail-page',
  imports: [
    UiPageHeader,
    UiCard,
    UiEmptyState,
    UiButton,
    UiBadge,
    UiListItem,
    UiAvatar,
    UiSkeleton,
    MoneyPipe,
    RouterLink,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header [heading]="contact()?.name ?? 'Contacto'" crumb="Finanzas · Compartidos" backLink="/finanzas/compartidos">
      @if (contact(); as current) {
        <button ui-button variant="secondary" size="sm" icon="pencil" aria-label="Editar contacto" (click)="edit(current)">
          <span class="d-only">Editar</span>
        </button>
        @if (current.shares_pending_cents > 0) {
          <button ui-button variant="primary" size="sm" icon="check" aria-label="Liquidar" (click)="settle(current)">
            <span class="d-only">Liquidar</span>
          </button>
        }
      }
    </ui-page-header>

    @if (detail.isLoading() && !contact()) {
      <ui-card><div class="stack"><ui-skeleton width="30%" height="42px" /><ui-skeleton width="60%" /></div></ui-card>
    } @else if (detail.error() && !contact()) {
      <ui-card>
        <ui-empty-state icon="circle-alert" heading="No encontramos este contacto" description="Puede que se haya eliminado.">
          <a ui-button size="sm" routerLink="/finanzas/compartidos">Volver a compartidos</a>
        </ui-empty-state>
      </ui-card>
    } @else if (contact(); as current) {
      <div class="stack">
        <ui-card>
          <div class="row hero">
            <ui-avatar [name]="current.name" [size]="48" />
            <div class="grow">
              <div class="caption">Saldo</div>
              <div class="display num" [class.pos]="current.balance_cents > 0">{{ balanceLabel() }}</div>
            </div>
            @if (current.archived) {
              <ui-badge icon="archive">Archivado</ui-badge>
            }
          </div>
          <div class="breakdown small">
            <div class="row between">
              <span class="muted">Gastos compartidos sin liquidar</span>
              <span class="num">{{ current.shares_pending_cents | money }}</span>
            </div>
            @if (current.owed_to_me_cents > 0) {
              <div class="row between">
                <span class="muted">Préstamos que te debe</span>
                <span class="num">{{ current.owed_to_me_cents | money }}</span>
              </div>
            }
            @if (current.i_owe_cents > 0) {
              <div class="row between">
                <span class="muted">Préstamos que le debes</span>
                <span class="num">{{ current.i_owe_cents | money }}</span>
              </div>
            }
          </div>
          @if (current.notes) {
            <p class="small muted notes">{{ current.notes }}</p>
          }
        </ui-card>

        <ui-card heading="Gastos compartidos" padding="list">
          @if (current.shares.length === 0) {
            <ui-empty-state
              icon="users"
              heading="Sin gastos compartidos"
              [description]="'Al registrar un gasto, actívale “Gasto compartido” y elige a ' + current.name + '.'"
            />
          } @else {
            <div class="ui-list">
              @for (share of current.shares; track share.id) {
                <ui-list-item [heading]="title(share)" [subtitle]="shareSubtitle(share)" [icon]="share.settled ? 'check' : 'receipt'" iconSoft>
                  @if (share.settled) {
                    <ui-badge badges tone="positive" icon="check">Liquidado</ui-badge>
                  } @else {
                    <ui-badge badges tone="warning" icon="clock">Pendiente</ui-badge>
                  }
                  <span trailing class="num value" [class.pos]="!share.settled" [class.muted]="share.settled">
                    {{ share.amount_cents | money: 'signed' }}
                  </span>
                </ui-list-item>
              }
            </div>
          }
        </ui-card>

        @if (current.debts.length) {
          <ui-card heading="Préstamos" padding="list">
            <a card-actions ui-button variant="ghost" size="sm" trailingIcon="chevron-right" routerLink="/finanzas/deudas">Deudas</a>
            <div class="ui-list">
              @for (debt of current.debts; track debt.id) {
                <a
                  ui-list-item
                  routerLink="/finanzas/deudas"
                  [heading]="debt.name"
                  [subtitle]="debtSubtitle(debt)"
                  [icon]="debt.direction === 'i_owe' ? 'arrow-up-right' : 'arrow-down-left'"
                  iconSoft
                  [value]="debt.pending_cents | money"
                  [valueTone]="debt.closed ? 'muted' : debt.direction === 'owed_to_me' ? 'positive' : 'default'"
                ></a>
              }
            </div>
          </ui-card>
        }
      </div>
    }
  `,
  styles: `
    .hero {
      gap: 16px;
      align-items: center;
    }
    .grow {
      flex: 1;
      min-width: 0;
    }
    .breakdown {
      margin-top: 16px;
      padding-top: 12px;
      border-top: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .notes {
      margin-top: 12px;
    }
    .value {
      font-weight: 550;
      white-space: nowrap;
    }
  `,
})
export class ContactDetailPage {
  private readonly service = inject(ContactsService);
  private readonly dialogs = inject(DialogService);

  readonly contactId = input.required<string>();

  protected readonly detail = resource({
    params: () => this.contactId(),
    loader: ({ params }) => this.service.get(params),
  });

  protected readonly contact = computed<FinanceContactDetail | undefined>(() =>
    this.detail.hasValue() ? this.detail.value() : undefined,
  );

  protected readonly balanceLabel = computed(() => {
    const contact = this.contact();
    return contact ? contactBalanceLabel(contact.balance_cents, (cents) => formatMoney(cents)) : '';
  });

  protected title(share: ContactShare): string {
    return shareTitle(share);
  }

  protected shareSubtitle(share: ContactShare): string {
    const total = formatMoney(Math.abs(share.transaction_amount_cents));
    return `${formatRelativeDay(share.date, undefined, 'title')} · total ${total}`;
  }

  protected debtSubtitle(debt: Debt): string {
    const parts = [DEBT_DIRECTION_LABELS[debt.direction]];
    if (debt.closed) {
      parts.push('saldada');
    } else if (debt.due_date) {
      parts.push(`vence ${formatShortDate(debt.due_date)}`);
    }
    return parts.join(' · ');
  }

  protected async edit(contact: FinanceContactDetail): Promise<void> {
    const ref = this.dialogs.open<ContactDialog, ContactDialogData, ContactDialogResult>(ContactDialog, { data: { contact } });
    const result = await firstValueFrom(ref.closed);
    if (result && result !== 'deleted') {
      this.detail.reload();
    }
  }

  protected async settle(contact: FinanceContactDetail): Promise<void> {
    const ref = this.dialogs.open<SettleDialog, SettleDialogData>(SettleDialog, {
      data: { contact, onUndone: () => this.detail.reload() },
    });
    const result = await firstValueFrom(ref.closed);
    if (result) {
      this.detail.reload();
    }
  }
}
