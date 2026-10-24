import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { DEFAULT_GOAL_ICON, GOAL_ICONS, SavingsGoal, SavingsGoalPayload } from '@finance/data-access/goals.models';
import { GoalsService } from '@finance/data-access/goals.service';
import { accountOptions, FinanceAccountLookup } from '@finance/data-access/recurring.models';
import { addMonths, IsoDate, todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiCategoryOption, UiCategoryPicker } from '@ui/category-picker/category-picker';
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

export interface GoalDialogData {
  goal: SavingsGoal | null;
}

type ProgressSource = 'manual' | 'account';

const ICON_LABELS: Record<(typeof GOAL_ICONS)[number], string> = {
  'piggy-bank': 'Hucha',
  shield: 'Emergencias',
  plane: 'Viaje',
  laptop: 'Tecnología',
  house: 'Casa',
  car: 'Coche',
  gift: 'Regalo',
  'graduation-cap': 'Estudios',
  heart: 'Salud',
  smartphone: 'Móvil',
  'tree-palm': 'Vacaciones',
  target: 'Otro',
};

const ICON_OPTIONS: UiCategoryOption[] = GOAL_ICONS.map((icon) => ({ id: icon, name: ICON_LABELS[icon], icon }));

const SOURCE_OPTIONS: UiSegmentedOption<ProgressSource>[] = [
  { value: 'manual', label: 'Aportaciones' },
  { value: 'account', label: 'Saldo de una cuenta' },
];

@Component({
  selector: 'app-finance-goal-dialog',
  imports: [
    ReactiveFormsModule,
    UiDialog,
    UiButton,
    UiField,
    UiInput,
    UiMoneyInput,
    UiDatePicker,
    UiSwitch,
    UiSegmented,
    UiSelect,
    UiCategoryPicker,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="goal ? 'Editar objetivo' : 'Nuevo objetivo'">
      <form [formGroup]="form" (ngSubmit)="save()" id="goal-form" class="form">
        <ui-money-input formControlName="target" ariaLabel="Importe meta" />
        @if (showError('target')) {
          <p class="field-error center" role="alert">Indica cuánto quieres ahorrar.</p>
        }

        <ui-field label="Nombre" for="goal-name" [error]="showError('name') ? 'Ponle un nombre al objetivo.' : null">
          <input ui-input id="goal-name" formControlName="name" placeholder="Fondo de emergencia, Viaje a Japón…" autocomplete="off" [invalid]="showError('name')" />
        </ui-field>

        <ui-field label="Icono">
          <ui-category-picker [categories]="iconOptions" formControlName="icon" [columns]="6" ariaLabel="Icono del objetivo" />
        </ui-field>

        <div class="toggle">
          <ui-switch formControlName="has_date" label="Tiene fecha objetivo" />
          <span>Tiene fecha objetivo</span>
        </div>
        @if (hasDate()) {
          <ui-field label="Fecha objetivo" hint="Calculamos cuánto aportar cada mes para llegar a tiempo.">
            <ui-date-picker formControlName="target_date" ariaLabel="Fecha objetivo" [min]="today" />
          </ui-field>
        }

        <ui-field label="Cómo se mide el progreso" [hint]="sourceHint()">
          <ui-segmented [options]="sourceOptions" formControlName="source" ariaLabel="Origen del progreso" />
        </ui-field>
        @if (source() === 'account') {
          <ui-field label="Cuenta" for="goal-account" [error]="accountError()">
            <ui-select inputId="goal-account" [options]="accounts()" formControlName="account_id" placeholder="Elige una cuenta de ahorro" />
          </ui-field>
        }

        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
      </form>
      <div dialog-footer class="footer">
        @if (goal) {
          <button ui-button type="button" variant="ghost" icon="trash" class="danger-text" [disabled]="saving()" (click)="remove()">
            Eliminar
          </button>
        }
        <span class="spacer"></span>
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="goal-form" variant="primary" [loading]="saving()">
          {{ goal ? 'Guardar' : 'Crear objetivo' }}
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
    .toggle {
      display: flex;
      align-items: center;
      gap: 10px;
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
  `,
})
export class GoalDialog implements OnInit {
  protected readonly ref = inject<DialogRef<SavingsGoal | 'deleted'>>(DialogRef);
  private readonly data = inject<GoalDialogData>(DIALOG_DATA);
  private readonly service = inject(GoalsService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);

  protected readonly goal = this.data.goal;
  protected readonly today = todayIso();
  protected readonly iconOptions = ICON_OPTIONS;
  protected readonly sourceOptions = SOURCE_OPTIONS;

  protected readonly form = new FormGroup({
    name: new FormControl(this.goal?.name ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    target: new FormControl<number | null>(this.goal?.target_cents ?? null, [Validators.required, Validators.min(1)]),
    icon: new FormControl<string | null>(this.goal?.icon ?? DEFAULT_GOAL_ICON),
    has_date: new FormControl(!!this.goal?.target_date, { nonNullable: true }),
    target_date: new FormControl<IsoDate | null>(this.goal?.target_date ?? addMonths(todayIso(), 12)),
    source: new FormControl<ProgressSource>(this.goal?.account_id ? 'account' : 'manual', { nonNullable: true }),
    account_id: new FormControl<string | null>(this.goal?.account_id ?? null),
  });

  private readonly accountLookups = signal<FinanceAccountLookup[]>([]);
  protected readonly accounts = computed(() => {
    const lookups = [...this.accountLookups()].sort((a, b) => Number(b.type === 'savings') - Number(a.type === 'savings'));
    return accountOptions(lookups);
  });
  protected readonly hasDate = toSignal(this.form.controls.has_date.valueChanges, { initialValue: this.form.controls.has_date.value });
  protected readonly source = toSignal(this.form.controls.source.valueChanges, { initialValue: this.form.controls.source.value });
  private readonly status = toSignal(this.form.statusChanges, { initialValue: this.form.status });
  protected readonly submitted = signal(false);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly sourceHint = computed(() =>
    this.source() === 'account'
      ? 'El progreso es el saldo de la cuenta: ahorra con transferencias a ella.'
      : 'Registra aportaciones a mano cuando apartes dinero.',
  );
  protected readonly accountError = computed(() => {
    this.status();
    return this.submitted() && this.source() === 'account' && !this.form.controls.account_id.value ? 'Elige una cuenta.' : null;
  });

  async ngOnInit(): Promise<void> {
    this.accountLookups.set(await this.service.accounts().catch(() => []));
    if (!this.form.controls.account_id.value) {
      const savings = this.accountLookups().find((account) => account.type === 'savings');
      this.form.controls.account_id.setValue(savings?.id ?? null);
    }
  }

  protected showError(name: 'name' | 'target'): boolean {
    this.status();
    const control = this.form.controls[name];
    return control.invalid && (this.submitted() || control.touched);
  }

  async save(): Promise<void> {
    this.submitted.set(true);
    this.form.markAllAsTouched();
    const value = this.form.getRawValue();
    if (this.form.invalid || (value.source === 'account' && !value.account_id)) {
      return;
    }
    const payload: SavingsGoalPayload = {
      name: value.name.trim(),
      target_cents: value.target!,
      target_date: value.has_date ? value.target_date : null,
      account_id: value.source === 'account' ? value.account_id : null,
      icon: value.icon,
    };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved = this.goal ? await this.service.update(this.goal.id, payload) : await this.service.create(payload);
      this.toast.show(this.goal ? 'Objetivo actualizado' : 'Objetivo creado');
      this.ref.close(saved);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar el objetivo.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async remove(): Promise<void> {
    if (!this.goal) {
      return;
    }
    const confirmed = await this.dialogs.confirm({
      title: `¿Eliminar ${this.goal.name}?`,
      message: 'Se borrará el objetivo y su historial de aportaciones. Tus cuentas y movimientos no cambian.',
      confirmLabel: 'Eliminar',
      danger: true,
    });
    if (!confirmed) {
      return;
    }
    this.saving.set(true);
    try {
      await this.service.remove(this.goal.id);
      this.toast.show(`${this.goal.name} eliminado`);
      this.ref.close('deleted');
      await this.router.navigateByUrl('/finanzas/objetivos');
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido eliminar el objetivo.'));
    } finally {
      this.saving.set(false);
    }
  }
}
