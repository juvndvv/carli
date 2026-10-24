import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiIcon } from '@ui/icon/icon';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSwitch } from '@ui/switch/switch';
import { AccountsService } from '../../data-access/accounts.service';
import { CHART_TOKENS } from '../../data-access/finance-format';
import {
  Account,
  ACCOUNT_TYPE_ICONS,
  ACCOUNT_TYPE_LABELS,
  AccountInput,
  AccountType,
  ChartToken,
} from '../../data-access/finance.models';
import { ACCOUNT_ICON_CHOICES } from '../../ui/finance-icons';

export interface AccountFormData {
  account?: Account | null;
}

@Component({
  selector: 'fin-account-form-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiMoneyInput, UiSelect, UiSwitch, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="account ? 'Editar cuenta' : 'Nueva cuenta'">
      <form class="stack" [formGroup]="form" (ngSubmit)="save()" novalidate>
        <ui-field label="Nombre" for="fin-account-name" [error]="submitted() && form.controls.name.invalid ? 'Ponle un nombre.' : null">
          <input ui-input id="fin-account-name" formControlName="name" placeholder="Ej. Cuenta corriente" autocomplete="off" />
        </ui-field>
        <ui-field label="Tipo" for="fin-account-type">
          <ui-select inputId="fin-account-type" formControlName="type" [options]="typeOptions" />
        </ui-field>
        <div class="grid-cards g-2">
          <ui-field label="Saldo inicial" for="fin-account-initial" [hint]="isCard() ? 'En negativo si ya debías algo.' : null">
            <ui-money-input appearance="field" inputId="fin-account-initial" ariaLabel="Saldo inicial" allowNegative formControlName="initial_balance_cents" />
          </ui-field>
          <ui-field label="Fecha del saldo inicial" for="fin-account-date">
            <input ui-input type="date" id="fin-account-date" formControlName="initial_balance_date" />
          </ui-field>
        </div>
        @if (isCard()) {
          <ui-field label="Límite de crédito" for="fin-account-limit">
            <ui-money-input appearance="field" inputId="fin-account-limit" ariaLabel="Límite de crédito" formControlName="credit_limit_cents" />
          </ui-field>
          <div class="grid-cards g-2">
            <ui-field label="Día de corte" for="fin-account-statement">
              <input ui-input type="number" min="1" max="31" inputmode="numeric" id="fin-account-statement" formControlName="statement_day" />
            </ui-field>
            <ui-field label="Día de cargo" for="fin-account-payment">
              <input ui-input type="number" min="1" max="31" inputmode="numeric" id="fin-account-payment" formControlName="payment_day" />
            </ui-field>
          </div>
        }
        <div class="field">
          <span class="field-label">Icono</span>
          <div class="choices" role="radiogroup" aria-label="Icono">
            @for (icon of iconChoices; track icon) {
              <button
                type="button"
                role="radio"
                class="choice"
                [class.on]="form.controls.icon.value === icon"
                [attr.aria-checked]="form.controls.icon.value === icon"
                [attr.aria-label]="icon"
                (click)="form.controls.icon.setValue(icon); form.markAsDirty()"
              >
                <ui-icon [name]="icon" />
              </button>
            }
          </div>
        </div>
        <div class="field">
          <span class="field-label">Color en gráficos</span>
          <div class="choices" role="radiogroup" aria-label="Color">
            @for (color of colors; track color; let index = $index) {
              <button
                type="button"
                role="radio"
                class="swatch"
                [class.on]="form.controls.color.value === color"
                [attr.aria-checked]="form.controls.color.value === color"
                [attr.aria-label]="'Color ' + (index + 1)"
                [style.background]="'var(--' + color + ')'"
                (click)="form.controls.color.setValue(color); form.markAsDirty()"
              ></button>
            }
          </div>
        </div>
        <div class="row between">
          <span>
            Sumar al patrimonio neto
            <span class="small faint block">Desactívalo para dinero que no es tuyo.</span>
          </span>
          <ui-switch formControlName="include_in_net_worth" label="Sumar al patrimonio neto" />
        </div>
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
        <button ui-button type="submit" variant="primary" size="lg" block [loading]="saving()">
          {{ account ? 'Guardar cambios' : 'Crear cuenta' }}
        </button>
      </form>
    </ui-dialog>
  `,
  styles: `
    .choices {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .choice {
      width: 40px;
      height: 40px;
      border-radius: 999px;
      border: 0;
      background: var(--surface-2);
      color: var(--text);
      display: grid;
      place-items: center;
    }
    .choice.on {
      background: var(--primary);
      color: var(--on-primary);
    }
    .swatch {
      width: 32px;
      height: 32px;
      border-radius: 999px;
      border: 2px solid var(--surface);
      box-shadow: 0 0 0 1px var(--border);
    }
    .swatch.on {
      box-shadow: 0 0 0 2px var(--text);
    }
    .block {
      display: block;
    }
  `,
})
export class AccountFormDialog {
  private readonly data = inject<AccountFormData | null>(DIALOG_DATA, { optional: true });
  private readonly ref = inject<DialogRef<Account>>(DialogRef);
  private readonly accounts = inject(AccountsService);

  protected readonly account = this.data?.account ?? null;
  protected readonly iconChoices = ACCOUNT_ICON_CHOICES;
  protected readonly colors: readonly ChartToken[] = CHART_TOKENS;
  protected readonly typeOptions: UiSelectOption<AccountType>[] = (Object.keys(ACCOUNT_TYPE_LABELS) as AccountType[]).map(
    (type) => ({ value: type, label: ACCOUNT_TYPE_LABELS[type], icon: ACCOUNT_TYPE_ICONS[type] }),
  );
  protected readonly saving = signal(false);
  protected readonly submitted = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly form = new FormGroup({
    name: new FormControl(this.account?.name ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    type: new FormControl<AccountType>(this.account?.type ?? 'checking', { nonNullable: true }),
    initial_balance_cents: new FormControl<number | null>(this.account?.initial_balance_cents ?? 0),
    initial_balance_date: new FormControl<string>(this.account?.initial_balance_date ?? todayIso(), { nonNullable: true }),
    credit_limit_cents: new FormControl<number | null>(this.account?.credit_limit_cents ?? null),
    statement_day: new FormControl<number | null>(this.account?.statement_day ?? null, [Validators.min(1), Validators.max(31)]),
    payment_day: new FormControl<number | null>(this.account?.payment_day ?? null, [Validators.min(1), Validators.max(31)]),
    icon: new FormControl<string | null>(this.account?.icon ?? null),
    color: new FormControl<string | null>(this.account?.color ?? null),
    include_in_net_worth: new FormControl(this.account?.include_in_net_worth ?? true, { nonNullable: true }),
  });

  private readonly type = toSignal(this.form.controls.type.valueChanges, { initialValue: this.form.controls.type.value });
  protected readonly isCard = computed(() => this.type() === 'credit_card');

  constructor() {
    this.form.controls.type.valueChanges.subscribe((type) => {
      const icon = this.form.controls.icon.value;
      if (!icon || Object.values(ACCOUNT_TYPE_ICONS).includes(icon)) {
        this.form.controls.icon.setValue(ACCOUNT_TYPE_ICONS[type]);
      }
    });
    if (!this.account) {
      this.form.controls.icon.setValue(ACCOUNT_TYPE_ICONS.checking);
    }
  }

  protected async save(): Promise<void> {
    this.submitted.set(true);
    this.error.set(null);
    if (this.form.invalid) {
      return;
    }
    const value = this.form.getRawValue();
    const card = value.type === 'credit_card';
    const input: AccountInput = {
      name: value.name.trim(),
      type: value.type,
      initial_balance_cents: value.initial_balance_cents ?? 0,
      initial_balance_date: value.initial_balance_date || null,
      credit_limit_cents: card ? value.credit_limit_cents : null,
      statement_day: card ? value.statement_day : null,
      payment_day: card ? value.payment_day : null,
      icon: value.icon,
      color: value.color,
      include_in_net_worth: value.include_in_net_worth,
    };
    this.saving.set(true);
    try {
      const saved = this.account ? await this.accounts.update(this.account.id, input) : await this.accounts.create(input);
      this.ref.close(saved);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar la cuenta.'));
    } finally {
      this.saving.set(false);
    }
  }
}
