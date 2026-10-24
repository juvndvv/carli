import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { FinanceContact, SettleContactResult } from '@finance/data-access/contacts.models';
import { ContactsService } from '@finance/data-access/contacts.service';
import { accountOptions, FinanceAccountLookup, preferredAccountId } from '@finance/data-access/recurring.models';
import { IsoDate, todayIso } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { UiButton } from '@ui/button/button';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiSelect } from '@ui/select/select';
import { ToastService } from '@ui/toast/toast.service';

export interface SettleDialogData {
  contact: FinanceContact;
  onUndone?: () => void;
}

@Component({
  selector: 'app-finance-settle-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiSelect, UiDatePicker],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="'Liquidar con ' + contact.name" subtitle="Registra el cobro de los gastos compartidos pendientes.">
      <form [formGroup]="form" (ngSubmit)="settle()" id="settle-form" class="form">
        <div class="amount">
          <span class="caption">{{ contact.name }} te paga</span>
          <span class="display num pos">{{ amountLabel }}</span>
        </div>
        <ui-field label="Cuenta donde lo recibes" for="settle-account">
          <ui-select inputId="settle-account" [options]="accounts()" formControlName="account_id" placeholder="Elige una cuenta" />
        </ui-field>
        <ui-field label="Fecha">
          <ui-date-picker formControlName="date" ariaLabel="Fecha del cobro" [max]="today" />
        </ui-field>
        <p class="small muted">Se crea un ingreso que no cuenta como ingreso del periodo: solo te devuelve lo que adelantaste.</p>
        @if (contact.i_owe_cents > 0 || contact.owed_to_me_cents > 0) {
          <p class="small faint">Las deudas con {{ contact.name }} se gestionan aparte, en Deudas.</p>
        }
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
      </form>
      <div dialog-footer class="footer">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="settle-form" variant="primary" icon="check" [loading]="saving()">
          Registrar cobro
        </button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .form {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .amount {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
      padding: 8px 0;
    }
    .footer {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
  `,
})
export class SettleDialog implements OnInit {
  protected readonly ref = inject<DialogRef<SettleContactResult>>(DialogRef);
  private readonly data = inject<SettleDialogData>(DIALOG_DATA);
  private readonly service = inject(ContactsService);
  private readonly toast = inject(ToastService);

  protected readonly contact = this.data.contact;
  protected readonly today = todayIso();
  protected readonly amountLabel = formatMoney(this.contact.shares_pending_cents, 'signed');

  protected readonly form = new FormGroup({
    account_id: new FormControl<string | null>(null, Validators.required),
    date: new FormControl<IsoDate | null>(todayIso(), Validators.required),
  });

  private readonly accountLookups = signal<FinanceAccountLookup[]>([]);
  protected readonly accounts = computed(() => accountOptions(this.accountLookups()));
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    const accounts = await this.service.accounts().catch(() => []);
    this.accountLookups.set(accounts);
    this.form.controls.account_id.setValue(preferredAccountId(accounts));
  }

  async settle(): Promise<void> {
    if (this.form.invalid) {
      this.error.set('Elige la cuenta donde recibes el dinero.');
      return;
    }
    const value = this.form.getRawValue();
    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.service.settle(this.contact.id, { account_id: value.account_id!, date: value.date! });
      const accountName = this.accountLookups().find((account) => account.id === value.account_id)?.name;
      this.toast.withUndo(
        `Liquidado con ${this.contact.name}: ${formatMoney(result.net_cents, 'signed')}${accountName ? ' en ' + accountName : ''}`,
        async () => {
          for (const transaction of result.transactions) {
            await this.service.undoSettlement(transaction.id);
          }
          this.data.onUndone?.();
        },
      );
      this.ref.close(result);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido liquidar.'));
    } finally {
      this.saving.set(false);
    }
  }
}
