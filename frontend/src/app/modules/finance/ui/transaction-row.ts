import { booleanAttribute, ChangeDetectionStrategy, Component, computed, inject, input, output } from '@angular/core';
import { formatMoney } from '@shared/money/money';
import { UiBadge } from '@ui/badge/badge';
import { UiIcon } from '@ui/icon/icon';
import { UiListItem } from '@ui/list-item/list-item';
import { AccountsService } from '../data-access/accounts.service';
import { transactionAmountLabel, transactionTitle, transactionTone } from '../data-access/finance-format';
import { Transaction } from '../data-access/finance.models';
import { FALLBACK_CATEGORY_ICON } from '../data-access/categories.service';

export function sharedSummary(transaction: Transaction): string | null {
  const pending = transaction.shares.filter((share) => !share.settled);
  if (pending.length === 0) {
    return null;
  }
  const total = pending.reduce((sum, share) => sum + share.amount_cents, 0);
  return pending.length === 1
    ? `${pending[0].name} te debe ${formatMoney(total)}`
    : `Te deben ${formatMoney(total)}`;
}

export function transactionIcon(transaction: Transaction): string {
  if (transaction.kind === 'transfer') {
    return 'arrow-left-right';
  }
  if (transaction.kind === 'adjustment') {
    return 'scale';
  }
  if (transaction.splits.length > 0) {
    return 'split';
  }
  return transaction.category?.icon ?? FALLBACK_CATEGORY_ICON;
}

@Component({
  selector: 'fin-transaction-row',
  imports: [UiListItem, UiBadge, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class.selected]': 'selected()' },
  template: `
    <button
      type="button"
      ui-list-item
      [heading]="title()"
      [subtitle]="subtitle()"
      [value]="amount()"
      [valueTone]="tone()"
      [attr.aria-pressed]="selectable() ? selected() : null"
      (click)="activate.emit(transaction())"
    >
      <span leading class="lead" [class.check]="selectable()" [class.soft]="!selectable() && isUncategorized()">
        @if (selectable()) {
          <ui-icon [name]="selected() ? 'circle-check' : 'circle'" />
        } @else {
          <ui-icon [name]="icon()" />
        }
      </span>
      @if (hasBadges()) {
        <span badges class="badges">
            @if (transaction().uncategorized) {
              <ui-badge tone="warning" icon="circle-dashed">Por revisar</ui-badge>
            }
            @if (transaction().source === 'bank') {
              <ui-badge icon="landmark" class="origin" title="Importado del banco">
                <span class="sr-only">Importado del banco</span>
              </ui-badge>
            }
            @if (transaction().status === 'pending') {
              <ui-badge tone="warning" icon="clock">Pendiente</ui-badge>
            }
            @if (transaction().shares.length > 0) {
              <ui-badge tone="primary" icon="users">Compartido</ui-badge>
            }
            @if (transaction().splits.length > 0) {
              <ui-badge icon="split">Dividido</ui-badge>
            }
            @for (tag of transaction().tags; track tag) {
              <ui-badge>#{{ tag }}</ui-badge>
            }
        </span>
      }
    </button>
  `,
  styles: `
    :host {
      display: block;
      border-bottom: 1px solid var(--border);
    }
    :host(:last-child) {
      border-bottom: 0;
    }
    .lead {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      flex: none;
      background: var(--surface-2);
      color: var(--text);
    }
    .lead.soft {
      color: var(--text-2);
    }
    .lead.check {
      background: none;
      color: var(--text-2);
    }
    :host(.selected) .lead.check {
      background: var(--primary);
      color: var(--on-primary);
    }
    :host(.selected) button {
      background: var(--primary-soft);
    }
    .badges {
      display: contents;
    }
    .origin {
      padding: 0 6px;
    }
  `,
})
export class FinTransactionRow {
  private readonly accounts = inject(AccountsService);

  readonly transaction = input.required<Transaction>();
  readonly selectable = input(false, { transform: booleanAttribute });
  readonly selected = input(false, { transform: booleanAttribute });
  readonly showAccount = input(true, { transform: booleanAttribute });
  readonly activate = output<Transaction>();

  protected readonly title = computed(() => transactionTitle(this.transaction()));
  protected readonly amount = computed(() => transactionAmountLabel(this.transaction()));
  protected readonly tone = computed(() => transactionTone(this.transaction()));
  protected readonly icon = computed(() => transactionIcon(this.transaction()));
  protected readonly isUncategorized = computed(() => {
    const transaction = this.transaction();
    return transaction.kind === 'transfer' || transaction.kind === 'adjustment' || (!transaction.category && transaction.splits.length === 0);
  });
  protected readonly hasBadges = computed(() => {
    const transaction = this.transaction();
    return (
      transaction.uncategorized ||
      transaction.source === 'bank' ||
      transaction.status === 'pending' ||
      transaction.shares.length > 0 ||
      transaction.splits.length > 0 ||
      transaction.tags.length > 0
    );
  });
  protected readonly subtitle = computed(() => {
    const transaction = this.transaction();
    const parts: string[] = [];
    if (transaction.kind === 'transfer') {
      const other = this.accounts.find(transaction.transfer_account_id)?.name;
      const route = other
        ? transaction.amount_cents < 0
          ? `${transaction.account.name} → ${other}`
          : `${other} → ${transaction.account.name}`
        : transaction.account.name;
      parts.push('Transferencia', route);
    } else {
      if (transaction.kind === 'adjustment') {
        parts.push('Ajuste');
      } else if (transaction.splits.length > 0) {
        parts.push(`${transaction.splits.length} categorías`);
      } else {
        parts.push(transaction.category?.name ?? 'Sin categoría');
      }
      if (this.showAccount()) {
        parts.push(transaction.account.name);
      }
      if (transaction.payee && transaction.description) {
        parts.push(transaction.description);
      }
    }
    const shared = sharedSummary(transaction);
    if (shared) {
      parts.push(shared);
    }
    return parts.join(' · ');
  });
}
