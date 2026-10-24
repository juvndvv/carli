import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import {
  accountOptions,
  categoryOptions,
  FinanceAccountLookup,
  FinanceCategoryLookup,
  FREQUENCY_PRESETS,
  FrequencyPreset,
  presetToSchedule,
  preferredAccountId,
  RecurringKind,
  RecurringMode,
  RecurringRule,
  RecurringRulePayload,
  scheduleToPreset,
} from '@finance/data-access/recurring.models';
import { RecurringService } from '@finance/data-access/recurring.service';
import { addMonths, IsoDate, todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSwitch } from '@ui/switch/switch';
import { ToastService } from '@ui/toast/toast.service';

export interface RecurringRuleDialogData {
  rule: RecurringRule | null;
  isSubscription?: boolean;
}

export type RecurringRuleDialogResult = 'saved' | 'deleted';

const KIND_OPTIONS: UiSegmentedOption<RecurringKind>[] = [
  { value: 'expense', label: 'Gasto' },
  { value: 'income', label: 'Ingreso' },
];

const MODE_OPTIONS: UiSegmentedOption<RecurringMode>[] = [
  { value: 'auto', label: 'Automático', icon: 'zap' },
  { value: 'confirm', label: 'Con confirmación', icon: 'hand' },
];

@Component({
  selector: 'app-finance-recurring-rule-dialog',
  imports: [
    ReactiveFormsModule,
    UiDialog,
    UiButton,
    UiField,
    UiInput,
    UiMoneyInput,
    UiSegmented,
    UiSelect,
    UiDatePicker,
    UiSwitch,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="isEdit ? 'Editar recurrente' : 'Nuevo recurrente'">
      <form [formGroup]="form" (ngSubmit)="save()" class="form" id="recurring-rule-form">
        <ui-segmented [options]="kindOptions" formControlName="kind" ariaLabel="Tipo" class="kind" />

        <ui-money-input
          formControlName="amount"
          [sign]="kind() === 'income' ? 'positive' : 'negative'"
          ariaLabel="Importe de cada cargo"
        />
        @if (showError('amount')) {
          <p class="field-error center" role="alert">Indica un importe mayor que cero.</p>
        }

        <ui-field label="Nombre" for="rr-payee" [error]="showError('payee') ? 'Ponle un nombre, por ejemplo Netflix.' : null">
          <input ui-input id="rr-payee" formControlName="payee" placeholder="Netflix, Alquiler, Nómina…" autocomplete="off" [invalid]="showError('payee')" />
        </ui-field>

        <div class="two">
          <ui-field label="Cuenta" for="rr-account" [error]="showError('account_id') ? 'Elige una cuenta.' : null">
            <ui-select inputId="rr-account" [options]="accounts()" formControlName="account_id" placeholder="Elige una cuenta" />
          </ui-field>
          <ui-field label="Categoría" for="rr-category">
            <ui-select inputId="rr-category" [options]="categories()" formControlName="category_id" placeholder="Sin categoría" />
          </ui-field>
        </div>

        <div class="two">
          <ui-field label="Frecuencia" for="rr-frequency">
            <ui-select inputId="rr-frequency" [options]="frequencyOptions" formControlName="preset" />
          </ui-field>
          @if (preset() === 'every_days' || preset() === 'every_months') {
            <ui-field [label]="preset() === 'every_days' ? 'Cada cuántos días' : 'Cada cuántos meses'" for="rr-interval">
              <input ui-input id="rr-interval" type="number" min="1" max="365" inputmode="numeric" formControlName="interval" />
            </ui-field>
          }
        </div>

        <ui-field label="Primer cargo">
          <ui-date-picker formControlName="start_date" ariaLabel="Fecha del primer cargo" />
        </ui-field>

        <div class="toggle">
          <ui-switch formControlName="has_end" label="Tiene fecha de fin" />
          <span>Tiene fecha de fin</span>
        </div>
        @if (hasEnd()) {
          <ui-field label="Último cargo" [error]="endError()">
            <ui-date-picker formControlName="end_date" ariaLabel="Fecha del último cargo" [min]="startDate()" />
          </ui-field>
        }

        <ui-field label="Al llegar la fecha" [hint]="modeHint()">
          <ui-segmented [options]="modeOptions" formControlName="mode" ariaLabel="Modo" />
        </ui-field>

        <div class="two">
          <ui-field label="Avisarme antes (días)" for="rr-remind" hint="Push a las 09:00">
            <input ui-input id="rr-remind" type="number" min="0" max="30" inputmode="numeric" formControlName="remind_days_before" />
          </ui-field>
          <div class="toggle end">
            <ui-switch formControlName="is_subscription" label="Es una suscripción" />
            <span>Es una suscripción</span>
          </div>
        </div>

        @if (formError()) {
          <p class="field-error" role="alert">{{ formError() }}</p>
        }
      </form>

      <div dialog-footer class="footer">
        @if (isEdit) {
          <button ui-button type="button" variant="ghost" icon="trash" class="danger-text" (click)="remove()" [disabled]="saving()">
            Eliminar
          </button>
        }
        <span class="spacer"></span>
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="recurring-rule-form" variant="primary" [loading]="saving()">
          {{ isEdit ? 'Guardar' : 'Crear recurrente' }}
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
    .kind {
      align-self: center;
    }
    .center {
      text-align: center;
      margin-top: -8px;
    }
    .two {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      align-items: start;
    }
    .toggle {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 15px;
    }
    .toggle.end {
      align-self: center;
      padding-top: 18px;
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
      .toggle.end {
        padding-top: 0;
      }
    }
  `,
})
export class RecurringRuleDialog implements OnInit {
  protected readonly ref = inject<DialogRef<RecurringRuleDialogResult>>(DialogRef);
  private readonly data = inject<RecurringRuleDialogData>(DIALOG_DATA);
  private readonly service = inject(RecurringService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);

  protected readonly isEdit = this.data.rule !== null;
  protected readonly kindOptions = KIND_OPTIONS;
  protected readonly modeOptions = MODE_OPTIONS;
  protected readonly frequencyOptions = FREQUENCY_PRESETS;

  protected readonly form = buildRecurringForm(this.data.rule, this.data.isSubscription ?? false);

  private readonly accountLookups = signal<FinanceAccountLookup[]>([]);
  private readonly categoryLookups = signal<FinanceCategoryLookup[]>([]);
  protected readonly saving = signal(false);
  protected readonly submitted = signal(false);
  protected readonly formError = signal<string | null>(null);

  protected readonly kind = toSignal(this.form.controls.kind.valueChanges, { initialValue: this.form.controls.kind.value });
  protected readonly preset = toSignal(this.form.controls.preset.valueChanges, { initialValue: this.form.controls.preset.value });
  protected readonly hasEnd = toSignal(this.form.controls.has_end.valueChanges, { initialValue: this.form.controls.has_end.value });
  protected readonly startDate = toSignal(this.form.controls.start_date.valueChanges, {
    initialValue: this.form.controls.start_date.value,
  });
  private readonly mode = toSignal(this.form.controls.mode.valueChanges, { initialValue: this.form.controls.mode.value });
  private readonly status = toSignal(this.form.statusChanges, { initialValue: this.form.status });

  protected readonly accounts = computed(() => accountOptions(this.accountLookups()));
  protected readonly categories = computed(() => [
    { value: null, label: 'Sin categoría', icon: 'circle' },
    ...categoryOptions(this.categoryLookups(), this.kind()),
  ]);
  protected readonly modeHint = computed(() =>
    this.mode() === 'auto'
      ? 'Se registra solo, ya confirmado.'
      : 'Se crea pendiente y te avisamos para que lo confirmes.',
  );
  protected readonly endError = computed(() => {
    this.status();
    return this.submitted() && this.form.hasError('endBeforeStart') ? 'Debe ser posterior al primer cargo.' : null;
  });

  async ngOnInit(): Promise<void> {
    const [accounts, categories] = await Promise.all([
      this.service.accounts().catch(() => []),
      this.service.categories().catch(() => []),
    ]);
    this.accountLookups.set(accounts);
    this.categoryLookups.set(categories);
    if (!this.form.controls.account_id.value) {
      this.form.controls.account_id.setValue(preferredAccountId(accounts));
    }
    this.form.controls.has_end.valueChanges.subscribe((hasEnd) => {
      const start = this.form.controls.start_date.value ?? todayIso();
      if (hasEnd && !this.form.controls.end_date.value) {
        this.form.controls.end_date.setValue(addMonths(start, 12));
      }
    });
    this.form.controls.kind.valueChanges.subscribe((kind) => {
      const selected = this.form.controls.category_id.value;
      const match = categories.find((category) => category.id === selected);
      if (match && match.kind !== kind) {
        this.form.controls.category_id.setValue(null);
      }
    });
  }

  protected showError(name: keyof RecurringForm['controls']): boolean {
    this.status();
    const control = this.form.controls[name];
    return control.invalid && (this.submitted() || control.touched);
  }

  async save(): Promise<void> {
    this.submitted.set(true);
    this.formError.set(null);
    this.form.markAllAsTouched();
    if (this.form.invalid) {
      return;
    }
    const payload = recurringPayloadFromForm(this.form);
    this.saving.set(true);
    try {
      if (this.data.rule) {
        await this.service.update(this.data.rule.id, payload);
        this.toast.show('Recurrente actualizado');
      } else {
        await this.service.create(payload);
        this.toast.show('Recurrente creado');
      }
      this.ref.close('saved');
    } catch (error) {
      this.formError.set(firstValidationMessage(error, 'No se ha podido guardar el recurrente.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async remove(): Promise<void> {
    const rule = this.data.rule;
    if (!rule) {
      return;
    }
    const confirmed = await this.dialogs.confirm({
      title: `¿Eliminar ${rule.name}?`,
      message: 'Se borrarán también los cargos pendientes de confirmar. Los movimientos ya registrados se mantienen.',
      confirmLabel: 'Eliminar',
      danger: true,
    });
    if (!confirmed) {
      return;
    }
    this.saving.set(true);
    try {
      await this.service.remove(rule.id);
      this.toast.show(`${rule.name} eliminado`);
      this.ref.close('deleted');
    } catch (error) {
      this.formError.set(firstValidationMessage(error, 'No se ha podido eliminar el recurrente.'));
    } finally {
      this.saving.set(false);
    }
  }
}

export type RecurringForm = ReturnType<typeof buildRecurringForm>;

export function buildRecurringForm(rule: RecurringRule | null, isSubscription: boolean) {
  const preset = rule ? scheduleToPreset(rule.frequency, rule.interval) : 'monthly';
  return new FormGroup(
    {
      kind: new FormControl<RecurringKind>(rule?.kind ?? 'expense', { nonNullable: true }),
      amount: new FormControl<number | null>(rule ? Math.abs(rule.amount_cents) : null, [
        Validators.required,
        Validators.min(1),
      ]),
      payee: new FormControl(rule?.payee ?? rule?.name ?? '', {
        nonNullable: true,
        validators: [Validators.required, Validators.maxLength(160)],
      }),
      account_id: new FormControl<string | null>(rule?.account_id ?? null, Validators.required),
      category_id: new FormControl<string | null>(rule?.category_id ?? null),
      preset: new FormControl<FrequencyPreset>(preset, { nonNullable: true }),
      interval: new FormControl<number>(rule && rule.interval > 1 ? rule.interval : 2, {
        nonNullable: true,
        validators: [Validators.min(1), Validators.max(365)],
      }),
      start_date: new FormControl<IsoDate | null>(rule?.start_date ?? todayIso(), Validators.required),
      has_end: new FormControl(rule?.end_date !== null && rule?.end_date !== undefined, { nonNullable: true }),
      end_date: new FormControl<IsoDate | null>(rule?.end_date ?? null),
      mode: new FormControl<RecurringMode>(rule?.mode ?? 'auto', { nonNullable: true }),
      remind_days_before: new FormControl<number>(rule?.remind_days_before ?? 2, {
        nonNullable: true,
        validators: [Validators.min(0), Validators.max(30)],
      }),
      is_subscription: new FormControl(rule?.is_subscription ?? isSubscription, { nonNullable: true }),
    },
    {
      validators: (group) => {
        const value = (group as FormGroup).getRawValue() as { has_end: boolean; end_date: IsoDate | null; start_date: IsoDate | null };
        if (!value.has_end || !value.end_date || !value.start_date) {
          return null;
        }
        return value.end_date < value.start_date ? { endBeforeStart: true } : null;
      },
    },
  );
}

export function recurringPayloadFromForm(form: RecurringForm): RecurringRulePayload {
  const value = form.getRawValue();
  const magnitude = Math.abs(value.amount ?? 0);
  const schedule = presetToSchedule(value.preset, value.interval);
  return {
    kind: value.kind,
    amount_cents: value.kind === 'expense' ? -magnitude : magnitude,
    payee: value.payee.trim(),
    account_id: value.account_id!,
    category_id: value.category_id,
    frequency: schedule.frequency,
    interval: schedule.interval,
    start_date: value.start_date!,
    end_date: value.has_end ? value.end_date : null,
    mode: value.mode,
    remind_days_before: value.remind_days_before,
    is_subscription: value.is_subscription,
  };
}
