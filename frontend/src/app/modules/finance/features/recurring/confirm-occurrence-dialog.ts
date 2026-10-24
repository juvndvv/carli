import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { ConfirmRecurringResult, frequencyLabel, RecurringRule } from '@finance/data-access/recurring.models';
import { RecurringService } from '@finance/data-access/recurring.service';
import { formatShortDate, IsoDate, todayIso } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { UiButton } from '@ui/button/button';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiIcon } from '@ui/icon/icon';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSwitch } from '@ui/switch/switch';
import { ToastService } from '@ui/toast/toast.service';

export interface ConfirmOccurrenceDialogData {
  rule: RecurringRule;
}

export interface PriceChange {
  direction: 'up' | 'down';
  differenceCents: number;
  percent: number;
}

export function detectPriceChange(expectedCents: number, actualCents: number | null): PriceChange | null {
  const expected = Math.abs(expectedCents);
  if (actualCents === null || actualCents <= 0 || actualCents === expected) {
    return null;
  }
  const difference = actualCents - expected;
  return {
    direction: difference > 0 ? 'up' : 'down',
    differenceCents: Math.abs(difference),
    percent: expected === 0 ? 0 : Math.round((Math.abs(difference) / expected) * 100),
  };
}

@Component({
  selector: 'app-finance-confirm-occurrence-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiMoneyInput, UiDatePicker, UiSwitch, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="heading" [subtitle]="subtitle">
      <form [formGroup]="form" (ngSubmit)="submit()" id="confirm-occurrence-form" class="form">
        <ui-money-input
          formControlName="amount"
          [sign]="rule.kind === 'income' ? 'positive' : 'negative'"
          ariaLabel="Importe cobrado"
        />
        <p class="small muted center">Previsto: {{ expectedLabel }}</p>

        @if (priceChange(); as change) {
          <div class="notice" role="status">
            <ui-icon [name]="change.direction === 'up' ? 'trending-up' : 'trending-down'" />
            <div class="notice-body">
              <strong>{{ changeTitle() }}</strong>
              <div class="toggle">
                <ui-switch formControlName="update_rule_amount" label="Usar este importe en los próximos cargos" />
                <span class="small">Usar este importe en los próximos cargos</span>
              </div>
            </div>
          </div>
        }

        <ui-field label="Fecha del cargo">
          <ui-date-picker formControlName="date" ariaLabel="Fecha del cargo" />
        </ui-field>

        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
      </form>
      <div dialog-footer class="footer">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="confirm-occurrence-form" variant="primary" icon="check" [loading]="saving()">
          Confirmar cargo
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
    .center {
      text-align: center;
      margin-top: -8px;
    }
    .notice {
      display: flex;
      gap: 12px;
      align-items: flex-start;
      padding: 12px 14px;
      border-radius: var(--r-md);
      background: var(--warning-soft);
      color: var(--warning);
    }
    .notice-body {
      display: flex;
      flex-direction: column;
      gap: 8px;
      color: var(--text);
    }
    .notice-body strong {
      font-weight: 600;
      color: var(--warning);
    }
    .toggle {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .footer {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
  `,
})
export class ConfirmOccurrenceDialog {
  protected readonly ref = inject<DialogRef<ConfirmRecurringResult>>(DialogRef);
  private readonly data = inject<ConfirmOccurrenceDialogData>(DIALOG_DATA);
  private readonly service = inject(RecurringService);
  private readonly toast = inject(ToastService);

  protected readonly rule = this.data.rule;
  private readonly occurrenceDate = this.rule.pending_transaction?.date ?? this.rule.next_occurrence ?? todayIso();
  private readonly expectedCents = this.rule.pending_transaction?.amount_cents ?? this.rule.amount_cents;

  protected readonly heading = `Confirmar ${this.rule.name}`;
  protected readonly subtitle = `${frequencyLabel(this.rule)} · cargo del ${formatShortDate(this.occurrenceDate)} · ${this.rule.account.name}`;
  protected readonly expectedLabel = formatMoney(this.rule.amount_cents, 'signed');

  protected readonly form = new FormGroup({
    amount: new FormControl<number | null>(Math.abs(this.expectedCents), [Validators.required, Validators.min(1)]),
    date: new FormControl<IsoDate | null>(this.occurrenceDate, Validators.required),
    update_rule_amount: new FormControl(true, { nonNullable: true }),
  });

  private readonly amount = toSignal(this.form.controls.amount.valueChanges, { initialValue: this.form.controls.amount.value });
  protected readonly priceChange = computed(() => detectPriceChange(this.rule.amount_cents, this.amount()));
  protected readonly changeTitle = computed(() => {
    const change = this.priceChange();
    if (!change) {
      return '';
    }
    const verb = change.direction === 'up' ? 'Sube' : 'Baja';
    return `${verb} ${formatMoney(change.differenceCents)} (${change.percent} %) respecto a lo previsto`;
  });
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  async submit(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid) {
      this.error.set('Indica un importe mayor que cero.');
      return;
    }
    const value = this.form.getRawValue();
    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.service.confirm(this.rule.id, {
        amount_cents: value.amount,
        date: value.date,
        update_rule_amount: this.priceChange() !== null && value.update_rule_amount,
      });
      const amount = formatMoney(result.transaction.amount_cents, 'signed');
      const suffix = result.price_changed && value.update_rule_amount ? ' · importe actualizado' : '';
      this.toast.show(`${this.rule.name} confirmado: ${amount}${suffix}`);
      this.ref.close(result);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido confirmar el cargo.'));
    } finally {
      this.saving.set(false);
    }
  }
}
