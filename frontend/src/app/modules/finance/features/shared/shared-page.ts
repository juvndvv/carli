import { ChangeDetectionStrategy, Component, computed, inject, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { contactBalanceLabel, FinanceContact } from '@finance/data-access/contacts.models';
import { ContactsService } from '@finance/data-access/contacts.service';
import { formatMoney } from '@shared/money/money';
import { UiAvatar } from '@ui/avatar/avatar';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { ContactDialog, ContactDialogData } from './contact-dialog';
import { SettleDialog, SettleDialogData } from './settle-dialog';

export function contactSubtitle(contact: FinanceContact): string {
  const parts: string[] = [];
  if (contact.shares_pending_cents > 0) {
    parts.push(`${formatMoney(contact.shares_pending_cents)} en gastos sin liquidar`);
  }
  if (contact.owed_to_me_cents > 0) {
    parts.push(`te debe ${formatMoney(contact.owed_to_me_cents)} en préstamos`);
  }
  if (contact.i_owe_cents > 0) {
    parts.push(`le debes ${formatMoney(contact.i_owe_cents)} en préstamos`);
  }
  return parts.length ? capitalizeFirst(parts.join(' · ')) : 'Sin nada pendiente';
}

function capitalizeFirst(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

@Component({
  selector: 'app-finance-shared-page',
  imports: [RouterLink, UiPageHeader, UiCard, UiEmptyState, UiButton, UiStat, UiListItem, UiAvatar, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Compartidos" crumb="Finanzas">
      <button ui-button variant="primary" size="sm" icon="user-plus" aria-label="Nuevo contacto" (click)="create()">
        <span class="d-only">Nuevo contacto</span>
      </button>
    </ui-page-header>

    <div class="grid-cards g-2 stats">
      <ui-stat label="Te deben" icon="arrow-down-left" tone="positive" [value]="owedToMe()" [delta]="owedToMeDelta()" />
      <ui-stat label="Debes" icon="arrow-up-right" [value]="iOwe()" [delta]="iOweDelta()" />
    </div>

    <ui-card heading="Gastos compartidos" padding="list" class="block">
      @if (service.loading() && !service.loaded()) {
        <div class="ui-list" aria-busy="true">
          @for (row of skeletonRows; track row) {
            <div class="skeleton-row">
              <ui-skeleton width="36px" height="36px" radius="999px" />
              <div class="grow"><ui-skeleton width="40%" /><ui-skeleton width="60%" height="12px" /></div>
            </div>
          }
        </div>
      } @else if (service.error() && !service.loaded()) {
        <ui-empty-state icon="circle-alert" heading="No se han podido cargar" [description]="service.error()">
          <button ui-button size="sm" icon="refresh-cw" (click)="service.load()">Reintentar</button>
        </ui-empty-state>
      } @else if (service.contacts().length === 0) {
        <ui-empty-state
          icon="users"
          heading="Aún no compartes gastos"
          description="Añade a las personas con las que compartes gastos. Al registrar un gasto podrás repartirlo con ellas."
        >
          <button ui-button variant="primary" size="sm" icon="user-plus" (click)="create()">Nuevo contacto</button>
        </ui-empty-state>
      } @else {
        <div class="ui-list">
          @for (contact of service.contacts(); track contact.id) {
            <div class="contact-row">
              <a ui-list-item [routerLink]="['/finanzas/compartidos', contact.id]" [heading]="contact.name" [subtitle]="subtitle(contact)">
                <ui-avatar leading [name]="contact.name" />
                <span trailing class="num value" [class.pos]="contact.balance_cents > 0" [class.muted]="contact.balance_cents === 0">
                  {{ balance(contact) }}
                </span>
              </a>
              @if (contact.shares_pending_cents > 0) {
                <button ui-button variant="ghost" size="sm" [attr.aria-label]="'Liquidar con ' + contact.name" (click)="settle(contact)">
                  Liquidar
                </button>
              }
            </div>
          }
        </div>
      }
    </ui-card>
  `,
  styles: `
    .stats {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
    .block {
      margin-top: 16px;
    }
    .contact-row {
      display: flex;
      align-items: center;
      gap: 4px;
      border-bottom: 1px solid var(--border);
    }
    .contact-row:last-child {
      border-bottom: 0;
    }
    .contact-row > a {
      flex: 1;
      min-width: 0;
      border-bottom: 0;
    }
    .value {
      font-weight: 550;
      white-space: nowrap;
    }
    .skeleton-row {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 4px;
    }
    .grow {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
  `,
})
export class SharedPage implements OnInit {
  protected readonly service = inject(ContactsService);
  private readonly dialogs = inject(DialogService);

  protected readonly skeletonRows = [0, 1, 2];
  protected readonly owedToMe = computed(() => formatMoney(this.service.meta().owed_to_me_cents));
  protected readonly iOwe = computed(() => formatMoney(this.service.meta().i_owe_cents));
  protected readonly owedToMeDelta = computed(() => peopleLabel(this.service.owingMe().length));
  protected readonly iOweDelta = computed(() => peopleLabel(this.service.owedByMe().length));

  ngOnInit(): void {
    void this.service.load();
  }

  protected subtitle(contact: FinanceContact): string {
    return contactSubtitle(contact);
  }

  protected balance(contact: FinanceContact): string {
    return contactBalanceLabel(contact.balance_cents, (cents) => formatMoney(cents));
  }

  protected create(): void {
    this.dialogs.open<ContactDialog, ContactDialogData>(ContactDialog, { data: { contact: null } });
  }

  protected settle(contact: FinanceContact): void {
    this.dialogs.open<SettleDialog, SettleDialogData>(SettleDialog, { data: { contact } });
  }
}

function peopleLabel(count: number): string {
  if (count === 0) {
    return 'Nadie';
  }
  return count === 1 ? '1 persona' : `${count} personas`;
}
