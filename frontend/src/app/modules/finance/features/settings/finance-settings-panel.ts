import { ChangeDetectionStrategy, Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiListItem } from '@ui/list-item/list-item';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiSwitch } from '@ui/switch/switch';
import { ToastService } from '@ui/toast/toast.service';
import { AccountsService } from '../../data-access/accounts.service';
import { CategoriesService } from '../../data-access/categories.service';
import { FinanceSettingsService } from '../../data-access/finance-settings.service';
import { ACCOUNT_TYPE_ICONS, Category, Period, PeriodMode, PeriodOpenedBy } from '../../data-access/finance.models';
import { PeriodsService } from '../../data-access/periods.service';
import { registerFinanceIcons } from '../../ui/finance-icons';
import { PeriodDateDialog, PeriodDateDialogData } from './period-date-dialog';

const OPENED_BY_LABELS: Record<PeriodOpenedBy, string> = {
  payroll: 'Por nómina',
  manual: 'Manual',
  calendar: 'Mes natural',
};

@Component({
  selector: 'fin-settings-panel',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    UiCard,
    UiField,
    UiInput,
    UiSelect,
    UiSegmented,
    UiSwitch,
    UiButton,
    UiBadge,
    UiListItem,
    UiSkeleton,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid-cards g-2">
      <ui-card heading="General">
        @if (loaded()) {
          <form class="stack" [formGroup]="form" (ngSubmit)="save()">
            <ui-field label="Cuenta por defecto" for="fin-settings-account" hint="Si no eliges ninguna, se usa la última con la que apuntaste un movimiento.">
              <ui-select
                inputId="fin-settings-account"
                formControlName="default_account_id"
                placeholder="La última usada"
                [options]="accountOptions()"
              />
            </ui-field>
            <ui-field
              label="Aviso de presupuesto (%)"
              for="fin-settings-threshold"
              hint="Te avisamos al llegar a este porcentaje y al superar el 100 %."
              [error]="fieldError('budget_warning_threshold', 'Entre 1 y 100.')"
            >
              <input ui-input type="number" inputmode="numeric" min="1" max="100" id="fin-settings-threshold" formControlName="budget_warning_threshold" />
            </ui-field>
            <ui-field
              label="Avisar de cargos recurrentes"
              for="fin-settings-remind"
              hint="Días de antelación para el aviso push."
              [error]="fieldError('remind_days_before', 'Entre 0 y 30 días.')"
            >
              <input ui-input type="number" inputmode="numeric" min="0" max="30" id="fin-settings-remind" formControlName="remind_days_before" />
            </ui-field>
            <div class="field">
              <span class="field-label">Periodo financiero</span>
              <ui-segmented formControlName="period_mode" ariaLabel="Periodo financiero" [options]="modeOptions" />
              <span class="field-hint">
                @if (form.controls.period_mode.value === 'payroll') {
                  Cada periodo empieza el día que registras la nómina y termina el día antes de la siguiente.
                } @else {
                  Cada periodo va del día 1 al último día del mes.
                }
              </span>
            </div>
            @if (form.controls.period_mode.value === 'payroll') {
              <ui-field
                label="Días mínimos entre nóminas"
                for="fin-settings-min-days"
                hint="Una paga extra antes de este plazo no abre periodo nuevo."
                [error]="fieldError('period_min_days', 'Entre 1 y 60 días.')"
              >
                <input ui-input type="number" inputmode="numeric" min="1" max="60" id="fin-settings-min-days" formControlName="period_min_days" />
              </ui-field>
            }
            <div class="row end">
              <button ui-button type="submit" variant="primary" [loading]="saving()" [disabled]="form.pristine">Guardar</button>
            </div>
          </form>
        } @else {
          <div class="stack">
            <ui-skeleton height="44px" />
            <ui-skeleton height="44px" />
            <ui-skeleton height="44px" />
          </div>
        }
      </ui-card>

      <div class="stack">
        <ui-card heading="Bancos">
          <p class="small muted intro">Importa movimientos de Revolut, BBVA o MyInvestor y gestiona las reglas de categorización.</p>
          <a ui-button variant="secondary" size="sm" icon="landmark" routerLink="/finanzas/ajustes/bancos">Bancos y reglas</a>
        </ui-card>

        <ui-card heading="Categorías que abren periodo">
          <p class="small muted intro">Al registrar un ingreso de estas categorías empieza un periodo nuevo.</p>
          <div class="ui-list">
            @for (category of incomeCategories(); track category.id) {
              <ui-list-item [heading]="category.name" [icon]="category.icon ?? 'circle-dashed'">
                <ui-switch
                  trailing
                  [label]="'Abre periodo: ' + category.name"
                  [checked]="category.opens_period"
                  [disabled]="busyCategory() === category.id"
                  (checkedChange)="toggleOpensPeriod(category, $event)"
                />
              </ui-list-item>
            } @empty {
              <p class="small faint">No tienes categorías de ingreso.</p>
            }
          </div>
        </ui-card>

        <ui-card heading="Periodos">
          <div card-actions>
            <button ui-button type="button" variant="ghost" size="sm" icon="calendar-plus" (click)="openManual()">Abrir periodo</button>
          </div>
          <div class="ui-list">
            @for (period of recentPeriods(); track period.id) {
              <ui-list-item [heading]="period.name" [subtitle]="period.range_label + (period.is_current ? ' · ' + daysLabel(period) : '')">
                <span trailing class="row trailing">
                  @if (period.is_current) {
                    <ui-badge tone="primary">En curso</ui-badge>
                  } @else {
                    <ui-badge>{{ openedBy(period) }}</ui-badge>
                  }
                  <button
                    ui-button
                    type="button"
                    variant="ghost"
                    size="sm"
                    icon="pencil"
                    iconOnly
                    [attr.aria-label]="'Mover el inicio del ' + period.name"
                    (click)="moveStart(period)"
                  ></button>
                </span>
              </ui-list-item>
            } @empty {
              <ui-skeleton height="44px" />
            }
          </div>
        </ui-card>
      </div>
    </div>
  `,
  styles: `
    :host {
      display: block;
    }
    .end {
      justify-content: flex-end;
    }
    .intro {
      margin-top: -6px;
      margin-bottom: 4px;
    }
    .trailing {
      gap: 4px;
    }
  `,
})
export class FinanceSettingsPanel {
  private readonly settings = inject(FinanceSettingsService);
  private readonly accounts = inject(AccountsService);
  private readonly categories = inject(CategoriesService);
  private readonly periods = inject(PeriodsService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);

  protected readonly modeOptions: UiSegmentedOption<PeriodMode>[] = [
    { value: 'payroll', label: 'De nómina a nómina' },
    { value: 'calendar', label: 'Mes natural' },
  ];
  protected readonly saving = signal(false);
  protected readonly busyCategory = signal<string | null>(null);
  protected readonly serverErrors = signal<Record<string, string[]>>({});
  protected readonly loaded = this.settings.loaded;

  protected readonly form = new FormGroup({
    default_account_id: new FormControl<string | null>(null),
    budget_warning_threshold: new FormControl<number>(80, {
      nonNullable: true,
      validators: [Validators.required, Validators.min(1), Validators.max(100)],
    }),
    remind_days_before: new FormControl<number>(2, {
      nonNullable: true,
      validators: [Validators.required, Validators.min(0), Validators.max(30)],
    }),
    period_mode: new FormControl<PeriodMode>('payroll', { nonNullable: true }),
    period_min_days: new FormControl<number>(20, {
      nonNullable: true,
      validators: [Validators.required, Validators.min(1), Validators.max(60)],
    }),
  });

  protected readonly accountOptions = computed<UiSelectOption<string | null>[]>(() => [
    { value: null, label: 'La última usada' },
    ...this.accounts.active().map((account) => ({
      value: account.id,
      label: account.name,
      icon: account.icon ?? ACCOUNT_TYPE_ICONS[account.type],
    })),
  ]);
  protected readonly incomeCategories = computed(() => this.categories.topLevel('income'));
  protected readonly recentPeriods = computed(() => this.periods.all().slice(0, 6));

  constructor() {
    registerFinanceIcons();
    effect(() => {
      const settings = this.settings.settings();
      untracked(() => {
        if (settings && this.form.pristine) {
          this.form.reset({
            default_account_id: settings.default_account_id,
            budget_warning_threshold: settings.budget_warning_threshold,
            remind_days_before: settings.remind_days_before,
            period_mode: settings.period_mode,
            period_min_days: settings.period_min_days,
          });
        }
      });
    });
  }

  protected fieldError(name: keyof FinanceSettingsPanel['form']['controls'], fallback: string): string | null {
    const server = this.serverErrors()[name]?.[0];
    if (server) {
      return server;
    }
    const control = this.form.controls[name];
    return control.invalid && (control.dirty || control.touched) ? fallback : null;
  }

  protected openedBy(period: Period): string {
    return OPENED_BY_LABELS[period.opened_by];
  }

  protected daysLabel(period: Period): string {
    return period.days_remaining === 1 ? 'queda 1 día' : `quedan ${period.days_remaining} días`;
  }

  protected async save(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid) {
      return;
    }
    this.saving.set(true);
    this.serverErrors.set({});
    try {
      const value = this.form.getRawValue();
      const { periodsChanged } = await this.settings.update(value);
      this.form.markAsPristine();
      this.toast.show(periodsChanged ? 'Ajustes guardados · periodos recalculados' : 'Ajustes guardados');
    } catch (error) {
      this.serverErrors.set((error as { error?: { errors?: Record<string, string[]> } }).error?.errors ?? {});
      this.toast.error(firstValidationMessage(error, 'No se han podido guardar los ajustes.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async toggleOpensPeriod(category: Category, opensPeriod: boolean): Promise<void> {
    this.busyCategory.set(category.id);
    try {
      await this.categories.update(category.id, { opens_period: opensPeriod });
      this.toast.show(opensPeriod ? `${category.name} abrirá periodo` : `${category.name} ya no abre periodo`);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido actualizar la categoría.'));
      this.categories.reload();
    } finally {
      this.busyCategory.set(null);
    }
  }

  protected async openManual(): Promise<void> {
    const date = await this.askDate({
      title: 'Abrir periodo a mano',
      description: 'Útil si cobras en efectivo o se retrasa la nómina. El periodo anterior terminará el día antes.',
      confirmLabel: 'Abrir periodo',
    });
    if (!date) {
      return;
    }
    try {
      const period = await this.periods.open(date);
      this.toast.show(`Abierto el ${period.name.toLowerCase()}`);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido abrir el periodo.'));
    }
  }

  protected async moveStart(period: Period): Promise<void> {
    const date = await this.askDate({
      title: 'Mover inicio del periodo',
      description: `${period.label}. El periodo anterior se ajusta para terminar el día antes.`,
      confirmLabel: 'Mover inicio',
      initial: period.start_date,
    });
    if (!date || date === period.start_date) {
      return;
    }
    try {
      await this.periods.moveStart(period.id, date);
      this.toast.show('Inicio del periodo actualizado');
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido mover el periodo.'));
    }
  }

  private async askDate(data: PeriodDateDialogData): Promise<string | undefined> {
    const ref = this.dialogs.open<PeriodDateDialog, PeriodDateDialogData, string>(PeriodDateDialog, { data });
    return firstValueFrom(ref.closed);
  }
}
