import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { IsoDate, todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiCalendar } from '@ui/calendar/calendar';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';

export interface PeriodDateDialogData {
  title: string;
  description: string;
  confirmLabel: string;
  initial?: IsoDate;
}

@Component({
  selector: 'fin-period-date-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiCalendar],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="data.title" [subtitle]="data.description">
      <form class="stack" (submit)="$event.preventDefault(); confirm()">
        <ui-calendar class="calendar" [value]="date.value" (picked)="date.setValue($event)" />
        <ui-field label="Fecha de inicio" for="fin-period-date">
          <input ui-input type="date" id="fin-period-date" [formControl]="date" />
        </ui-field>
        <div class="row between">
          <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
          <button ui-button type="submit" variant="primary" [disabled]="date.invalid">{{ data.confirmLabel }}</button>
        </div>
      </form>
    </ui-dialog>
  `,
  styles: `
    .calendar {
      align-self: center;
    }
  `,
})
export class PeriodDateDialog {
  protected readonly data = inject<PeriodDateDialogData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<IsoDate>>(DialogRef);
  protected readonly date = new FormControl<string>(this.data.initial ?? todayIso(), {
    nonNullable: true,
    validators: [Validators.required, Validators.pattern(/^\d{4}-\d{2}-\d{2}$/)],
  });

  protected confirm(): void {
    if (this.date.valid) {
      this.ref.close(this.date.value);
    }
  }
}
