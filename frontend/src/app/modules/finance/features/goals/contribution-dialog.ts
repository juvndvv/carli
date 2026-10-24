import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { GoalContribution, goalPercent, SavingsGoal } from '@finance/data-access/goals.models';
import { GoalsService } from '@finance/data-access/goals.service';
import { IsoDate, todayIso } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { UiButton } from '@ui/button/button';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { ToastService } from '@ui/toast/toast.service';

export interface ContributionDialogData {
  goal: SavingsGoal;
}

export interface ContributionDialogResult {
  contribution: GoalContribution;
  goal: SavingsGoal;
}

type ContributionDirection = 'add' | 'withdraw';

const DIRECTION_OPTIONS: UiSegmentedOption<ContributionDirection>[] = [
  { value: 'add', label: 'Aportar', icon: 'plus' },
  { value: 'withdraw', label: 'Retirar', icon: 'minus' },
];

@Component({
  selector: 'app-finance-contribution-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiMoneyInput, UiDatePicker, UiSegmented],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Aportar" [subtitle]="subtitle">
      <form [formGroup]="form" (ngSubmit)="save()" id="contribution-form" class="form">
        <ui-segmented [options]="directionOptions" formControlName="direction" ariaLabel="Tipo de aportación" class="direction" />
        <ui-money-input
          formControlName="amount"
          [sign]="direction() === 'add' ? 'positive' : 'negative'"
          ariaLabel="Importe de la aportación"
        />
        <ui-field label="Fecha">
          <ui-date-picker formControlName="date" ariaLabel="Fecha de la aportación" [max]="today" />
        </ui-field>
        <ui-field label="Nota" for="contribution-note">
          <input ui-input id="contribution-note" formControlName="note" placeholder="Opcional" autocomplete="off" />
        </ui-field>
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
      </form>
      <div dialog-footer class="footer">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="contribution-form" variant="primary" [loading]="saving()">
          {{ direction() === 'add' ? 'Aportar' : 'Retirar' }}
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
    .direction {
      align-self: center;
    }
    .footer {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
  `,
})
export class ContributionDialog {
  protected readonly ref = inject<DialogRef<ContributionDialogResult>>(DialogRef);
  private readonly data = inject<ContributionDialogData>(DIALOG_DATA);
  private readonly service = inject(GoalsService);
  private readonly toast = inject(ToastService);

  protected readonly today = todayIso();
  protected readonly directionOptions = DIRECTION_OPTIONS;
  protected readonly subtitle = `${this.data.goal.name} · ${formatMoney(this.data.goal.saved_cents)} de ${formatMoney(this.data.goal.target_cents)}`;

  protected readonly form = new FormGroup({
    direction: new FormControl<ContributionDirection>('add', { nonNullable: true }),
    amount: new FormControl<number | null>(this.data.goal.monthly_needed_cents || null, [Validators.required, Validators.min(1)]),
    date: new FormControl<IsoDate | null>(todayIso(), Validators.required),
    note: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(255)] }),
  });

  protected readonly direction = toSignal(this.form.controls.direction.valueChanges, {
    initialValue: this.form.controls.direction.value,
  });
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  async save(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid) {
      this.error.set('Indica un importe mayor que cero.');
      return;
    }
    const value = this.form.getRawValue();
    const amount = value.direction === 'add' ? value.amount! : -value.amount!;
    this.saving.set(true);
    this.error.set(null);
    try {
      const result = await this.service.contribute(this.data.goal.id, {
        amount_cents: amount,
        date: value.date!,
        note: value.note.trim() || null,
      });
      const reached = result.goal.achieved && !this.data.goal.achieved;
      this.toast.show(
        reached
          ? `¡Objetivo conseguido! ${result.goal.name} al 100 %`
          : `${formatMoney(amount, 'signed')} · ${result.goal.name} al ${goalPercent(result.goal)} %`,
      );
      this.ref.close(result);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido registrar la aportación.'));
    } finally {
      this.saving.set(false);
    }
  }
}
