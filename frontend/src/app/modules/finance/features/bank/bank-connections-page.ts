import { ChangeDetectionStrategy, Component, computed, inject, input, OnDestroy, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { formatShortDate } from '@shared/dates/dates';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ToastService } from '@ui/toast/toast.service';
import { BANK_CALLBACK_ERRORS, BankConnection, bankConnectionState, BankLinkedAccount } from '../../data-access/bank.models';
import { BankRedirect, BankService } from '../../data-access/bank.service';
import { formatDateTime } from '../../data-access/finance-format';
import { CategoryRulesCard } from '../rules/category-rules-card';
import { ConnectBankDialog } from './connect-bank-dialog';

export const SYNC_POLL_INTERVAL_MS = 3000;
export const SYNC_POLL_ATTEMPTS = 10;

export const BANK_SETTINGS_PATH = '/finanzas/ajustes/bancos';

export function lastSyncLabel(connection: Pick<BankConnection, 'last_synced_at'>, now: Date = new Date()): string {
  return connection.last_synced_at ? `Sincronizado ${formatDateTime(connection.last_synced_at, now)}` : 'Aún no se ha sincronizado';
}

export function linkedAccountLabel(account: BankLinkedAccount): string {
  return account.sync_from_date ? `${account.name} · desde el ${formatShortDate(account.sync_from_date, true)}` : account.name;
}

function syncFinished(before: BankConnection, after: BankConnection): boolean {
  return after.last_synced_at !== before.last_synced_at || after.status !== before.status || after.last_error !== before.last_error;
}

@Component({
  selector: 'app-finance-bank-connections-page',
  imports: [RouterLink, UiPageHeader, UiCard, UiButton, UiBadge, UiIcon, UiSkeleton, UiEmptyState, CategoryRulesCard],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Bancos" crumb="Finanzas · Ajustes" backLink="/finanzas/ajustes">
      <button ui-button type="button" variant="primary" size="sm" icon="plus" (click)="connect()">
        <span class="d-only">Conectar banco</span>
      </button>
    </ui-page-header>

    @if (callbackError(); as message) {
      <div class="notice" role="alert">
        <ui-icon name="triangle-alert" />
        <span class="body small">{{ message }}</span>
        <button ui-button type="button" variant="ghost" size="sm" icon="x" iconOnly aria-label="Cerrar aviso" (click)="dismissError()"></button>
      </div>
    }

    <div class="stack">
      @if (!bank.loaded()) {
        <ui-card><ui-skeleton height="120px" /></ui-card>
      } @else if (bank.connections().length === 0) {
        <ui-card>
          <ui-empty-state
            icon="landmark"
            heading="Conecta tu banco"
            description="Importa los movimientos de Revolut, BBVA o MyInvestor automáticamente varias veces al día. Solo lectura: entran sin categoría y los revisas en Pendientes."
          >
            <button ui-button type="button" variant="primary" icon="plus" (click)="connect()">Conectar banco</button>
          </ui-empty-state>
        </ui-card>
      } @else {
        @for (connection of bank.connections(); track connection.id) {
          <ui-card>
            <div class="row between head">
              <span class="row identity">
                <span class="ico"><ui-icon name="landmark" /></span>
                <span class="names">
                  <span class="name">{{ connection.aspsp_name }}</span>
                  <span class="small faint">{{ syncLabel(connection) }}</span>
                </span>
              </span>
              <ui-badge [tone]="state(connection).tone">{{ state(connection).label }}</ui-badge>
            </div>

            @if (connection.status === 'error' && connection.last_error) {
              <p class="small error-text">{{ connection.last_error }}</p>
            }
            @if (connection.status === 'expired') {
              <p class="small muted">El permiso del banco ha caducado. Renuévalo para seguir importando movimientos.</p>
            }

            @if (connection.linked_accounts.length > 0) {
              <ul class="accounts small">
                @for (account of connection.linked_accounts; track account.id) {
                  <li>
                    <a [routerLink]="['/finanzas/cuentas', account.id]">{{ linkedLabel(account) }}</a>
                  </li>
                }
              </ul>
            } @else {
              <p class="small muted">Ninguna cuenta vinculada: no se importa nada de este banco.</p>
            }

            <div class="row actions">
              @if (state(connection).canSync) {
                <button
                  ui-button
                  type="button"
                  variant="secondary"
                  size="sm"
                  icon="refresh-cw"
                  [loading]="syncing() === connection.id"
                  [disabled]="connection.linked_accounts.length === 0"
                  (click)="sync(connection)"
                >
                  Sincronizar ahora
                </button>
              }
              @if (state(connection).canRenew) {
                <button
                  ui-button
                  type="button"
                  size="sm"
                  icon="key-round"
                  [variant]="state(connection).tone === 'positive' ? 'ghost' : 'primary'"
                  [loading]="renewing() === connection.id"
                  (click)="renew(connection)"
                >
                  Renovar
                </button>
              }
              <a ui-button variant="ghost" size="sm" icon="link" [routerLink]="[basePath, connection.id, 'vincular']">Cuentas</a>
              <button
                ui-button
                type="button"
                variant="ghost"
                size="sm"
                icon="trash"
                class="disconnect"
                [loading]="disconnecting() === connection.id"
                (click)="disconnect(connection)"
              >
                Desconectar
              </button>
            </div>
          </ui-card>
        }
      }

      <fin-category-rules-card />
    </div>
  `,
  styles: `
    .notice {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 8px 8px 16px;
      margin-bottom: 16px;
      border-radius: var(--r-md);
      background: var(--warning-soft);
      color: var(--warning);
    }
    .notice .body {
      flex: 1;
      color: var(--text);
    }
    .head {
      gap: 12px;
    }
    .identity {
      min-width: 0;
      gap: 12px;
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
    }
    .error-text {
      color: var(--negative);
      margin: 12px 0 0;
    }
    .accounts {
      margin: 12px 0 0;
      padding-left: 18px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .accounts a {
      color: var(--text);
    }
    .actions {
      margin-top: 14px;
      gap: 8px;
      flex-wrap: wrap;
    }
    .disconnect {
      margin-left: auto;
    }
    p {
      margin: 12px 0 0;
    }
  `,
})
export class BankConnectionsPage implements OnDestroy {
  protected readonly bank = inject(BankService);
  private readonly redirect = inject(BankRedirect);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);

  readonly error = input<string | null>(null);

  protected readonly basePath = BANK_SETTINGS_PATH;
  protected readonly syncing = signal<string | null>(null);
  protected readonly renewing = signal<string | null>(null);
  protected readonly disconnecting = signal<string | null>(null);
  private readonly dismissed = signal(false);
  private destroyed = false;

  protected readonly callbackError = computed(() => {
    const reason = this.error();
    if (!reason || this.dismissed()) {
      return null;
    }
    return BANK_CALLBACK_ERRORS[reason] ?? 'No se ha podido conectar el banco. Vuelve a intentarlo.';
  });

  ngOnDestroy(): void {
    this.destroyed = true;
  }

  protected state(connection: BankConnection) {
    return bankConnectionState(connection);
  }

  protected syncLabel(connection: BankConnection): string {
    return lastSyncLabel(connection);
  }

  protected linkedLabel(account: BankLinkedAccount): string {
    return linkedAccountLabel(account);
  }

  protected dismissError(): void {
    this.dismissed.set(true);
    void this.router.navigate([], { queryParams: { error: null }, queryParamsHandling: 'merge', replaceUrl: true });
  }

  protected connect(): void {
    this.dialogs.open(ConnectBankDialog);
  }

  protected async sync(connection: BankConnection): Promise<void> {
    this.syncing.set(connection.id);
    try {
      await this.bank.sync(connection.id);
      this.toast.show(`Sincronizando ${connection.aspsp_name}…`);
      await this.waitForSync(connection);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido sincronizar el banco.'));
    } finally {
      this.syncing.set(null);
    }
  }

  protected async renew(connection: BankConnection): Promise<void> {
    this.renewing.set(connection.id);
    try {
      this.redirect.go(await this.bank.renew(connection.id));
    } catch (error) {
      this.renewing.set(null);
      this.toast.error(firstValidationMessage(error, 'No se ha podido renovar el permiso del banco.'));
    }
  }

  protected async disconnect(connection: BankConnection): Promise<void> {
    const confirmed = await this.dialogs.confirm({
      title: `¿Desconectar ${connection.aspsp_name}?`,
      message:
        'Se revoca el permiso de lectura en el banco y se dejan de importar movimientos. Los movimientos ya importados se conservan en tus cuentas.',
      confirmLabel: 'Desconectar',
      danger: true,
    });
    if (!confirmed) {
      return;
    }
    this.disconnecting.set(connection.id);
    try {
      await this.bank.disconnect(connection.id);
      this.toast.show(`${connection.aspsp_name} desconectado · los movimientos importados se conservan`);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido desconectar el banco.'));
    } finally {
      this.disconnecting.set(null);
    }
  }

  private async waitForSync(before: BankConnection): Promise<void> {
    for (let attempt = 0; attempt < SYNC_POLL_ATTEMPTS && !this.destroyed; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, SYNC_POLL_INTERVAL_MS));
      const current = await this.bank.get(before.id);
      if (syncFinished(before, current)) {
        this.bank.synced();
        if (current.status === 'error') {
          this.toast.error(current.last_error ?? `No se ha podido sincronizar ${current.aspsp_name}.`);
        } else {
          this.toast.show(`${current.aspsp_name} sincronizado`);
        }
        return;
      }
    }
    this.bank.synced();
  }
}
