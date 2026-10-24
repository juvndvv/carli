import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { Debt, DEBT_DIRECTION_LABELS, DebtPayment, debtInstallmentsLabel } from '@finance/data-access/debts.models';
import { DebtsService } from '@finance/data-access/debts.service';
import { accountOptions, FinanceAccountLookup, preferredAccountId } from '@finance/data-access/recurring.models';
import { formatShortDate, IsoDate, todayIso } from '@shared/dates/dates';
import { RelativeDatePipe } from '@shared/dates/relative-date.pipe';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiField } from '@ui/field/field';
import { UiListItem } from '@ui/list-item/list-item';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiProgress } from '@ui/progress/progress';
import { UiSelect } from '@ui/select/select';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { DebtDialog, DebtDialogData } from './debt-dialog';

export interface DebtDetailDialogData {
  debt: Debt;
}

@Component({
  selector: 'app-finance-debt-detail-dialog',
  imports: [
    ReactiveFormsModule,
    UiDialog,
    UiButton,
    UiBadge,
    UiProgress,
    UiField,
    UiMoneyInput,
    UiSelect,
    UiDatePicker,
    UiListItem,
    UiSkeleton,
    MoneyPipe,
    RelativeDatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="debt().name" [subtitle]="subtitle()">
      <button dialog-actions ui-button type="button" variant="ghost" size="sm" icon="pencil" iconOnly aria-label="Editar deuda" (click)="edit()"></button>

      <div class="summary">
        <div class="row between">
          <ui-badge [tone]="debt().direction === 'i_owe' ? 'neutral' : 'positive'">{{ directionLabel() }}</ui-badge>
          @if (debt().closed) {
            <ui-badge tone="positive" icon="check">Saldada</ui-badge>
          } @else if (debt().next_payment_date) {
            <span class="small faint">Próx. {{ shortDate(debt().next_payment_date!) }}</span>
          } @else if (debt().due_date) {
            <span class="small faint">Vence {{ shortDate(debt().due_date!) }}</span>
          }
        </div>
        <div class="row between small amounts">
          <span class="muted">Pendiente <b class="num strong">{{ debt().pending_cents | money }}</b> de {{ debt().principal_cents | money }}</span>
          <span class="faint num">{{ percent() }} %</span>
        </div>
        <ui-progress tone="primary" [ratio]="debt().progress_bp / 10000" [label]="'Pagado de ' + debt().name" />
        @if (debt().notes) {
          <p class="small muted">{{ debt().notes }}</p>
        }
      </div>

      @if (!debt().closed) {
        <form [formGroup]="paymentForm" (ngSubmit)="addPayment()" class="payment">
          <h3>{{ paymentHeading() }}</h3>
          <div class="two">
            <ui-field label="Importe" for="debt-payment-amount">
              <ui-money-input inputId="debt-payment-amount" appearance="field" formControlName="amount" ariaLabel="Importe del pago" />
            </ui-field>
            <ui-field label="Cuenta" for="debt-payment-account">
              <ui-select inputId="debt-payment-account" [options]="accounts()" formControlName="account_id" placeholder="Elige una cuenta" />
            </ui-field>
          </div>
          <ui-field label="Fecha">
            <ui-date-picker formControlName="date" ariaLabel="Fecha del pago" />
          </ui-field>
          @if (error()) {
            <p class="field-error" role="alert">{{ error() }}</p>
          }
          <div class="row end">
            <button ui-button type="button" variant="ghost" size="sm" (click)="fillPending()">Todo lo pendiente</button>
            <button ui-button type="submit" variant="primary" size="sm" icon="plus" [loading]="saving()">{{ paymentHeading() }}</button>
          </div>
        </form>
      }

      <section>
        <h3>{{ debt().direction === 'i_owe' ? 'Pagos' : 'Cobros' }}</h3>
        @if (loadingPayments()) {
          <ui-skeleton height="40px" />
        } @else if (payments().length === 0) {
          <p class="small muted">Aún no hay {{ debt().direction === 'i_owe' ? 'pagos' : 'cobros' }} registrados.</p>
        } @else {
          <div class="ui-list">
            @for (payment of payments(); track payment.id) {
              <ui-list-item
                [heading]="payment.description || payment.payee || debt().name"
                [subtitle]="(payment.date | relativeDate: 'title') + ' · ' + payment.account.name"
                [icon]="debt().direction === 'i_owe' ? 'arrow-up-right' : 'arrow-down-left'"
                iconSoft
              >
                @if (payment.status === 'pending') {
                  <ui-badge badges tone="warning" icon="clock">Pendiente</ui-badge>
                }
                <span trailing class="trail">
                  <span class="num value" [class.pos]="payment.amount_cents > 0">{{ payment.amount_cents | money: 'signed' }}</span>
                  <button
                    ui-button
                    variant="ghost"
                    size="sm"
                    icon="trash"
                    iconOnly
                    [attr.aria-label]="'Borrar pago del ' + shortDate(payment.date)"
                    (click)="removePayment(payment)"
                  ></button>
                </span>
              </ui-list-item>
            }
          </div>
        }
      </section>

      <div dialog-footer class="footer">
        <button ui-button type="button" variant="ghost" icon="trash" class="danger-text" (click)="remove()">Eliminar</button>
        <span class="spacer"></span>
        <button ui-button type="button" variant="secondary" [icon]="debt().closed ? 'undo-2' : 'check'" (click)="toggleClosed()">
          {{ debt().closed ? 'Reabrir' : 'Marcar como saldada' }}
        </button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .summary,
    .payment,
    section {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .payment {
      padding: 16px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      gap: 12px;
    }
    h3 {
      font-size: 15px;
      font-weight: 600;
    }
    .amounts {
      margin-top: 4px;
    }
    .strong {
      color: var(--text);
    }
    .two {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }
    .end {
      justify-content: flex-end;
      gap: 8px;
    }
    .trail {
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .value {
      font-weight: 550;
      white-space: nowrap;
    }
    .footer {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .spacer {
      flex: 1;
    }
    .danger-text {
      color: var(--negative);
    }
    @media (max-width: 640px) {
      .two {
        grid-template-columns: minmax(0, 1fr);
      }
    }
  `,
})
export class DebtDetailDialog implements OnInit {
  private readonly ref = inject<DialogRef<void>>(DialogRef);
  private readonly data = inject<DebtDetailDialogData>(DIALOG_DATA);
  private readonly service = inject(DebtsService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);

  protected readonly debt = signal<Debt>(this.data.debt);
  protected readonly payments = signal<DebtPayment[]>([]);
  protected readonly loadingPayments = signal(true);
  private readonly accountLookups = signal<FinanceAccountLookup[]>([]);
  protected readonly accounts = computed(() => accountOptions(this.accountLookups()));
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly paymentForm = new FormGroup({
    amount: new FormControl<number | null>(this.data.debt.installment_cents ?? null, [Validators.required, Validators.min(1)]),
    account_id: new FormControl<string | null>(null, Validators.required),
    date: new FormControl<IsoDate | null>(todayIso(), Validators.required),
  });

  protected readonly directionLabel = computed(() => DEBT_DIRECTION_LABELS[this.debt().direction]);
  protected readonly percent = computed(() => Math.floor(this.debt().progress_bp / 100));
  protected readonly paymentHeading = computed(() => (this.debt().direction === 'i_owe' ? 'Registrar pago' : 'Registrar cobro'));
  protected readonly subtitle = computed(() => {
    const debt = this.debt();
    return [debt.contact?.name, debtInstallmentsLabel(debt, (cents) => formatMoney(cents))].filter(Boolean).join(' · ');
  });

  async ngOnInit(): Promise<void> {
    const [accounts] = await Promise.all([this.service.accounts().catch(() => []), this.loadPayments()]);
    this.accountLookups.set(accounts);
    this.paymentForm.controls.account_id.setValue(preferredAccountId(accounts));
  }

  protected shortDate(date: IsoDate): string {
    return formatShortDate(date);
  }

  protected fillPending(): void {
    this.paymentForm.controls.amount.setValue(this.debt().pending_cents);
  }

  async addPayment(): Promise<void> {
    this.paymentForm.markAllAsTouched();
    if (this.paymentForm.invalid) {
      this.error.set('Indica el importe y la cuenta.');
      return;
    }
    const value = this.paymentForm.getRawValue();
    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.service.addPayment(this.debt().id, {
        account_id: value.account_id!,
        amount_cents: value.amount!,
        date: value.date!,
      });
      this.debt.set(result.debt);
      await this.loadPayments();
      this.toast.show(result.debt.closed ? `${result.debt.name} saldada` : `${this.paymentHeading()}: ${formatMoney(result.payment.amount_cents, 'signed')}`);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido registrar el pago.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async removePayment(payment: DebtPayment): Promise<void> {
    try {
      await this.service.deletePayment(payment.id);
      await this.refresh();
      this.toast.withUndo('Pago borrado', async () => {
        await this.service.restorePayment(payment.id);
        await this.refresh();
      });
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido borrar el pago.'));
    }
  }

  protected async toggleClosed(): Promise<void> {
    const closing = !this.debt().closed;
    try {
      const updated = await this.service.update(this.debt().id, { closed: closing });
      this.debt.set(updated);
      if (closing) {
        this.toast.withUndo(`${updated.name} marcada como saldada`, async () => {
          this.debt.set(await this.service.update(updated.id, { closed: false }));
        });
      }
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido actualizar la deuda.'));
    }
  }

  protected async edit(): Promise<void> {
    const ref = this.dialogs.open<DebtDialog, DebtDialogData, Debt>(DebtDialog, { data: { debt: this.debt() } });
    const updated = await firstValueFrom(ref.closed);
    if (updated) {
      this.debt.set(updated);
    }
  }

  protected async remove(): Promise<void> {
    const debt = this.debt();
    const confirmed = await this.dialogs.confirm({
      title: `¿Eliminar ${debt.name}?`,
      message: 'Los pagos ya registrados se mantienen como movimientos. Si tenía cuotas, se elimina también su recurrente.',
      confirmLabel: 'Eliminar',
      danger: true,
    });
    if (!confirmed) {
      return;
    }
    try {
      await this.service.remove(debt.id);
      this.toast.show(`${debt.name} eliminada`);
      this.ref.close();
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido eliminar la deuda.'));
    }
  }

  private async loadPayments(): Promise<void> {
    this.loadingPayments.set(true);
    try {
      this.payments.set(await this.service.payments(this.debt().id));
    } catch {
      this.payments.set([]);
    } finally {
      this.loadingPayments.set(false);
    }
  }

  private async refresh(): Promise<void> {
    await this.loadPayments();
    await this.service.load();
    const current = this.service.debts().find((debt) => debt.id === this.debt().id);
    if (current) {
      this.debt.set(current);
    }
  }
}
