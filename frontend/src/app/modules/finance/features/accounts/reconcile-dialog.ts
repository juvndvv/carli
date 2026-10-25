import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { todayIso } from '@shared/dates/dates';
import { formatDateTime } from '../../data-access/finance-format';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { ToastService } from '@ui/toast/toast.service';
import { AccountsService } from '../../data-access/accounts.service';
import { Account, ReconcileResult } from '../../data-access/finance.models';

export interface ReconcileData {
  account: Account;
}

export function reconcileStartingBalance(account: Account): number {
  return account.bank?.balance_cents ?? account.cleared_balance_cents;
}

@Component({
  selector: 'fin-reconcile-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiMoneyInput, MoneyPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Conciliar cuenta" [subtitle]="account.name">
      <form class="stack" (submit)="$event.preventDefault(); save()" novalidate>
        <div class="row between small">
          <span class="muted">Saldo confirmado en la app</span>
          <span class="num strong">{{ account.cleared_balance_cents | money }}</span>
        </div>
        @if (account.balance_cents !== account.cleared_balance_cents) {
          <p class="small muted">No cuenta los movimientos pendientes ({{ account.balance_cents - account.cleared_balance_cents | money: 'signed' }}).</p>
        }
        <div class="field">
          <label class="field-label" for="fin-reconcile-amount">Saldo real en el banco</label>
          <ui-money-input inputId="fin-reconcile-amount" ariaLabel="Saldo real en el banco" allowNegative [formControl]="actual" />
          @if (bankBalance(); as bank) {
            <span class="field-hint">Precargado con el saldo que informa {{ bank.name }}{{ bank.at ? ' (' + bank.at + ')' : '' }}.</span>
          }
        </div>
        <ui-field label="Fecha" for="fin-reconcile-date">
          <input ui-input type="date" id="fin-reconcile-date" [formControl]="date" />
        </ui-field>
        @if (difference() !== null) {
          <p class="small" [class.muted]="difference() === 0">
            @if (difference() === 0) {
              El saldo cuadra. No hace falta ningún ajuste.
            } @else {
              Se creará un movimiento de ajuste de <b class="num">{{ difference() | money: 'signed' }}</b>.
            }
          </p>
        }
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
        <div class="row between">
          <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
          <button ui-button type="submit" variant="primary" icon="check-check" [loading]="saving()" [disabled]="actual.invalid">Conciliar</button>
        </div>
      </form>
    </ui-dialog>
  `,
  styles: `
    .strong {
      font-weight: 600;
    }
  `,
})
export class ReconcileDialog {
  protected readonly account = inject<ReconcileData>(DIALOG_DATA).account;
  protected readonly ref = inject<DialogRef<ReconcileResult>>(DialogRef);
  private readonly accounts = inject(AccountsService);
  private readonly toast = inject(ToastService);

  protected readonly actual = new FormControl<number | null>(reconcileStartingBalance(this.account), Validators.required);
  protected readonly bankBalance = computed(() => {
    const bank = this.account.bank;
    if (!bank || bank.balance_cents === null) {
      return null;
    }
    return { name: bank.aspsp_name, at: bank.balance_at ? formatDateTime(bank.balance_at) : null };
  });
  protected readonly date = new FormControl(todayIso(), { nonNullable: true });
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  private readonly actualValue = toSignal(this.actual.valueChanges, { initialValue: this.actual.value });
  protected readonly difference = computed(() => {
    const value = this.actualValue();
    return value === null ? null : value - this.account.cleared_balance_cents;
  });

  protected async save(): Promise<void> {
    const value = this.actual.value;
    if (value === null) {
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.accounts.reconcile(this.account.id, value, this.date.value || undefined);
      this.ref.close(result);
      this.toast.show(
        result.adjustment
          ? `Cuenta conciliada · ajuste de ${formatMoney(result.difference_cents, 'signed')}`
          : 'Cuenta conciliada · el saldo ya cuadraba',
      );
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido conciliar la cuenta.'));
    } finally {
      this.saving.set(false);
    }
  }
}
