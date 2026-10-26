import { booleanAttribute, ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { formatMoney } from '@shared/money/money';
import { UiIcon } from '@ui/icon/icon';
import { formatDateTime } from '../data-access/finance-format';
import { AccountBankLink } from '../data-access/finance.models';

export interface BankBalanceSummary {
  bank: string;
  balance: string | null;
  difference: string | null;
  matches: boolean;
  updated: string | null;
}

export function bankBalanceSummary(link: AccountBankLink | null | undefined, now: Date = new Date()): BankBalanceSummary | null {
  if (!link) {
    return null;
  }
  const difference = link.difference_cents;
  return {
    bank: link.aspsp_name,
    balance: link.balance_cents === null ? null : formatMoney(link.balance_cents),
    difference: difference === null || difference === 0 ? null : formatMoney(difference, 'signed'),
    matches: difference === 0,
    updated: link.balance_at ? formatDateTime(link.balance_at, now) : null,
  };
}

@Component({
  selector: 'fin-bank-balance',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (summary(); as info) {
      <div class="bank" [class.off]="info.difference !== null">
        <ui-icon name="landmark" [size]="14" />
        @if (info.balance === null) {
          <span>Vinculada a {{ info.bank }} · sin saldo todavía</span>
        } @else {
          <span>
            {{ info.bank }}: <b class="num">{{ info.balance }}</b>
            @if (info.matches) {
              · cuadra
            } @else if (info.difference) {
              · diferencia <b class="num">{{ info.difference }}</b>
            }
          </span>
        }
      </div>
      @if (info.updated && detailed()) {
        <div class="small faint updated">Saldo del banco {{ info.updated }}</div>
      }
    }
  `,
  styles: `
    :host {
      display: block;
    }
    .bank {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      color: var(--text-2);
    }
    .bank.off {
      color: var(--text-2);
    }
    .bank.off b {
      color: var(--text);
    }
    b {
      font-weight: 600;
      color: var(--text);
    }
    .updated {
      margin-top: 2px;
    }
  `,
})
export class FinBankBalance {
  readonly link = input<AccountBankLink | null>(null);
  readonly detailed = input(false, { transform: booleanAttribute });

  protected readonly summary = computed(() => bankBalanceSummary(this.link()));
}
