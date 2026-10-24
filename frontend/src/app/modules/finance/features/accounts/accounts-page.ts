import { CdkMenu, CdkMenuItem, CdkMenuTrigger } from '@angular/cdk/menu';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiProgress } from '@ui/progress/progress';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { AccountsService } from '../../data-access/accounts.service';
import { Account, ACCOUNT_TYPE_ICONS, ACCOUNT_TYPE_LABELS } from '../../data-access/finance.models';
import { AccountActions } from './account-actions';

export function cardSchedule(account: Account): string | null {
  const parts: string[] = [];
  if (account.statement_day) {
    parts.push(`Corte día ${account.statement_day}`);
  }
  if (account.payment_day) {
    parts.push(`se carga el día ${account.payment_day}`);
  }
  return parts.length ? parts.join(' · ') : null;
}

@Component({
  selector: 'app-finance-accounts-page',
  imports: [
    RouterLink,
    UiPageHeader,
    UiCard,
    UiButton,
    UiIcon,
    UiBadge,
    UiProgress,
    UiSkeleton,
    UiEmptyState,
    MoneyPipe,
    CdkMenuTrigger,
    CdkMenu,
    CdkMenuItem,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Cuentas" crumb="Finanzas">
      <button ui-button type="button" variant="primary" size="sm" icon="plus" (click)="actions.edit()">
        <span class="d-only">Nueva cuenta</span>
      </button>
    </ui-page-header>

    @if (!accounts.loaded()) {
      <ui-card class="hero"><ui-skeleton width="30%" height="12px" /><ui-skeleton width="50%" height="40px" class="gap" /></ui-card>
      <div class="grid-cards g-2">
        <ui-card><ui-skeleton height="140px" /></ui-card>
        <ui-card><ui-skeleton height="140px" /></ui-card>
      </div>
    } @else if (accounts.all().length === 0) {
      <ui-card>
        <ui-empty-state
          icon="landmark"
          heading="Aún no tienes cuentas"
          description="Crea tu cuenta corriente, tu tarjeta o el efectivo con su saldo actual y empieza a apuntar movimientos."
        >
          <button ui-button type="button" variant="primary" icon="plus" (click)="actions.edit()">Añadir cuenta</button>
        </ui-empty-state>
      </ui-card>
    } @else {
      <ui-card class="hero">
        <div class="caption">Patrimonio neto</div>
        <div class="display num">{{ accounts.netWorth() | money }}</div>
        <div class="small muted sub">{{ summary() }}</div>
      </ui-card>

      <div class="grid-cards g-2">
        @for (account of visible(); track account.id) {
          <ui-card [class.archived]="account.archived">
            <div class="row between">
              <a class="row identity" [routerLink]="['/finanzas/cuentas', account.id]">
                <span class="ico"><ui-icon [name]="icon(account)" /></span>
                <span class="names">
                  <span class="name">{{ account.name }}</span>
                  <span class="small faint">{{ typeLabel(account) }}{{ account.include_in_net_worth ? '' : ' · fuera del patrimonio' }}</span>
                </span>
              </a>
              <span class="row tools">
                @if (account.archived) {
                  <ui-badge icon="archive">Archivada</ui-badge>
                }
                <button
                  ui-button
                  type="button"
                  variant="ghost"
                  size="sm"
                  icon="ellipsis"
                  iconOnly
                  [attr.aria-label]="'Opciones de ' + account.name"
                  [cdkMenuTriggerFor]="menu"
                  [cdkMenuTriggerData]="{ $implicit: account }"
                ></button>
              </span>
            </div>
            <div class="num balance" [class.neg]="account.balance_cents < 0 && account.type !== 'credit_card'">
              {{ account.balance_cents | money }}
            </div>
            @if (account.type === 'credit_card' && account.credit_limit_cents) {
              <div class="credit">
                <ui-progress
                  tone="primary"
                  [value]="account.used_credit_cents ?? 0"
                  [max]="account.credit_limit_cents"
                  [label]="'Crédito dispuesto de ' + account.name"
                />
                <div class="row between small muted credit-line">
                  <span>Dispuesto {{ account.used_credit_cents ?? 0 | money }}</span>
                  <span>Disponible {{ account.available_credit_cents ?? 0 | money }}</span>
                </div>
                @if (schedule(account); as text) {
                  <div class="small faint">{{ text }}</div>
                }
              </div>
            } @else if (account.pending_cents !== 0) {
              <div class="small faint">Pendiente {{ account.pending_cents | money: 'signed' }} · confirmado {{ account.cleared_balance_cents | money }}</div>
            } @else {
              <div class="small faint">Todo confirmado</div>
            }
            <div class="row card-actions">
              <a ui-button variant="secondary" size="sm" icon="list" routerLink="/finanzas/movimientos" [queryParams]="{ cuenta: account.id }">
                Movimientos
              </a>
              <button ui-button type="button" variant="ghost" size="sm" icon="check-check" (click)="actions.reconcile(account)">Conciliar</button>
            </div>
          </ui-card>
        }
      </div>

      @if (accounts.archived().length > 0) {
        <button type="button" class="archived-toggle small faint" (click)="showArchived.set(!showArchived())">
          <ui-icon name="archive" [size]="14" />
          {{ archivedLabel() }} · {{ showArchived() ? 'ocultar' : 'mostrar' }}
        </button>
      }
    }

    <ng-template #menu let-account>
      <div class="ui-menu" cdkMenu>
        <a class="ui-menu-item" cdkMenuItem [routerLink]="['/finanzas/cuentas', account.id]"><ui-icon name="chart-line" />Ver detalle</a>
        <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="actions.edit(account)"><ui-icon name="pencil" />Editar</button>
        <button
          type="button"
          class="ui-menu-item"
          cdkMenuItem
          (cdkMenuItemTriggered)="actions.setIncludedInNetWorth(account, !account.include_in_net_worth)"
        >
          <ui-icon [name]="account.include_in_net_worth ? 'eye-off' : 'eye'" />
          {{ account.include_in_net_worth ? 'Excluir del patrimonio' : 'Incluir en el patrimonio' }}
        </button>
        <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="actions.setArchived(account, !account.archived)">
          <ui-icon [name]="account.archived ? 'archive-restore' : 'archive'" />
          {{ account.archived ? 'Desarchivar' : 'Archivar' }}
        </button>
        <button type="button" class="ui-menu-item danger" cdkMenuItem (cdkMenuItemTriggered)="actions.remove(account)">
          <ui-icon name="trash" />Eliminar
        </button>
      </div>
    </ng-template>
  `,
  styles: `
    .hero {
      margin-bottom: 16px;
    }
    .sub {
      margin-top: 4px;
    }
    .gap {
      margin-top: 8px;
    }
    .identity {
      min-width: 0;
      color: var(--text);
      text-decoration: none;
    }
    .identity:hover .name {
      text-decoration: underline;
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
    .names {
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .name {
      font-weight: 600;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .tools {
      gap: 4px;
    }
    .balance {
      font-size: 24px;
      line-height: 32px;
      font-weight: 650;
      margin-top: 16px;
      margin-bottom: 4px;
    }
    .credit {
      margin-top: 10px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .credit-line {
      margin-top: 2px;
    }
    .card-actions {
      margin-top: 14px;
      gap: 8px;
    }
    .archived {
      opacity: 0.75;
    }
    .archived-toggle {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      margin-top: 16px;
      border: 0;
      background: none;
      padding: 4px 0;
    }
  `,
})
export class AccountsPage {
  protected readonly accounts = inject(AccountsService);
  protected readonly actions = inject(AccountActions);
  protected readonly router = inject(Router);
  protected readonly showArchived = signal(false);

  protected readonly visible = computed(() =>
    this.showArchived() ? [...this.accounts.active(), ...this.accounts.archived()] : this.accounts.active(),
  );
  protected readonly summary = computed(() => {
    const count = this.accounts.active().length;
    const label = count === 1 ? '1 cuenta' : `${count} cuentas`;
    const hasCards = this.accounts.active().some((account) => account.type === 'credit_card');
    return hasCards ? `${label} · las tarjetas de crédito restan` : label;
  });
  protected readonly archivedLabel = computed(() => {
    const count = this.accounts.archived().length;
    return count === 1 ? '1 cuenta archivada' : `${count} cuentas archivadas`;
  });

  protected icon(account: Account): string {
    return account.icon ?? ACCOUNT_TYPE_ICONS[account.type];
  }

  protected typeLabel(account: Account): string {
    return ACCOUNT_TYPE_LABELS[account.type];
  }

  protected schedule(account: Account): string | null {
    return cardSchedule(account);
  }
}
