import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { TransactionStatus } from '../../data-access/finance.models';
import { TransactionFilters } from '../../data-access/transaction-filters';

export type MoreFilters = Pick<TransactionFilters, 'min' | 'max' | 'from' | 'to' | 'status'>;

@Component({
  selector: 'fin-more-filters-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiMoneyInput, UiSegmented],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Más filtros">
      <form class="stack" [formGroup]="form" (ngSubmit)="apply()">
        <div class="field">
          <span class="field-label">Estado</span>
          <ui-segmented formControlName="status" ariaLabel="Estado" [options]="statusOptions" />
        </div>
        <div class="grid-cards g-2 pair">
          <ui-field label="Importe mínimo" for="fin-filter-min">
            <ui-money-input appearance="field" inputId="fin-filter-min" ariaLabel="Importe mínimo" formControlName="min" />
          </ui-field>
          <ui-field label="Importe máximo" for="fin-filter-max">
            <ui-money-input appearance="field" inputId="fin-filter-max" ariaLabel="Importe máximo" formControlName="max" />
          </ui-field>
        </div>
        <p class="small faint hint">El importe se compara sin signo: sirve igual para gastos e ingresos.</p>
        <div class="grid-cards g-2 pair">
          <ui-field label="Desde" for="fin-filter-from" hint="Sustituye al periodo">
            <input ui-input type="date" id="fin-filter-from" formControlName="from" />
          </ui-field>
          <ui-field label="Hasta" for="fin-filter-to">
            <input ui-input type="date" id="fin-filter-to" formControlName="to" />
          </ui-field>
        </div>
        <div class="row between">
          <button ui-button type="button" variant="ghost" (click)="clear()">Limpiar</button>
          <button ui-button type="submit" variant="primary">Aplicar</button>
        </div>
      </form>
    </ui-dialog>
  `,
  styles: `
    .hint {
      margin-top: -8px;
    }
  `,
})
export class MoreFiltersDialog {
  private readonly data = inject<MoreFilters>(DIALOG_DATA);
  private readonly ref = inject<DialogRef<MoreFilters>>(DialogRef);

  protected readonly statusOptions: UiSegmentedOption<TransactionStatus | 'all'>[] = [
    { value: 'all', label: 'Todos' },
    { value: 'pending', label: 'Pendientes' },
    { value: 'cleared', label: 'Confirmados' },
  ];

  protected readonly form = new FormGroup({
    status: new FormControl<TransactionStatus | 'all'>(this.data.status ?? 'all', { nonNullable: true }),
    min: new FormControl<number | null>(this.data.min),
    max: new FormControl<number | null>(this.data.max),
    from: new FormControl<string>(this.data.from ?? '', { nonNullable: true }),
    to: new FormControl<string>(this.data.to ?? '', { nonNullable: true }),
  });

  protected clear(): void {
    this.form.setValue({ status: 'all', min: null, max: null, from: '', to: '' });
  }

  protected apply(): void {
    const value = this.form.getRawValue();
    this.ref.close({
      status: value.status === 'all' ? null : value.status,
      min: value.min,
      max: value.max,
      from: value.from || null,
      to: value.to || null,
    });
  }
}
