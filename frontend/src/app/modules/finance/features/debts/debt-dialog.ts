import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { ContactsService } from '@finance/data-access/contacts.service';
import { Debt, DebtDirection, DebtPayload } from '@finance/data-access/debts.models';
import { DebtsService } from '@finance/data-access/debts.service';
import {
  accountOptions,
  categoryOptions,
  FinanceAccountLookup,
  FinanceCategoryLookup,
  preferredAccountId,
} from '@finance/data-access/recurring.models';
import { addMonths, IsoDate, todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSwitch } from '@ui/switch/switch';
import { UiTextarea } from '@ui/textarea/textarea';
import { ToastService } from '@ui/toast/toast.service';

export interface DebtDialogData {
  debt: Debt | null;
  direction?: DebtDirection;
  contactId?: string | null;
}

export const NO_CONTACT = '__none';
export const NEW_CONTACT = '__new';

const DIRECTION_OPTIONS: UiSegmentedOption<DebtDirection>[] = [
  { value: 'i_owe', label: 'Debo', icon: 'arrow-up-right' },
  { value: 'owed_to_me', label: 'Me deben', icon: 'arrow-down-left' },
];

@Component({
  selector: 'app-finance-debt-dialog',
  imports: [
    ReactiveFormsModule,
    UiDialog,
    UiButton,
    UiField,
    UiInput,
    UiTextarea,
    UiMoneyInput,
    UiSegmented,
    UiSelect,
    UiDatePicker,
    UiSwitch,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="debt ? 'Editar deuda' : 'Nueva deuda'">
      <form [formGroup]="form" (ngSubmit)="save()" id="debt-form" class="form">
        <ui-segmented [options]="directionOptions" formControlName="direction" ariaLabel="Dirección" class="center-self" />
        <ui-money-input formControlName="principal" ariaLabel="Importe total" />
        @if (showError('principal')) {
          <p class="field-error center" role="alert">Indica el importe total.</p>
        }

        <ui-field label="Concepto" for="debt-name" [error]="showError('name') ? 'Ponle un nombre, por ejemplo Préstamo coche.' : null">
          <input ui-input id="debt-name" formControlName="name" placeholder="Préstamo coche, Dinero a Luis…" autocomplete="off" [invalid]="showError('name')" />
        </ui-field>

        <ui-field [label]="direction() === 'i_owe' ? 'A quién se lo debes' : 'Quién te lo debe'" for="debt-contact">
          <ui-select inputId="debt-contact" [options]="contactOptions()" formControlName="contact" />
        </ui-field>
        @if (contact() === newContact) {
          <ui-field label="Nombre del contacto" for="debt-contact-name" [error]="contactNameError()">
            <input ui-input id="debt-contact-name" formControlName="contact_name" placeholder="Cetelem, Luis…" autocomplete="off" />
          </ui-field>
        }

        <div class="two">
          <ui-field label="Fecha">
            <ui-date-picker formControlName="start_date" ariaLabel="Fecha de la deuda" />
          </ui-field>
          <div class="toggle">
            <ui-switch formControlName="has_due" label="Tiene fecha de vencimiento" />
            <span>Fecha de vencimiento</span>
          </div>
        </div>
        @if (hasDue()) {
          <ui-field label="Vence">
            <ui-date-picker formControlName="due_date" ariaLabel="Fecha de vencimiento" [min]="startDate()" />
          </ui-field>
        }

        @if (canPlan) {
          <div class="toggle">
            <ui-switch formControlName="has_plan" label="Pagar en cuotas" />
            <span>{{ direction() === 'i_owe' ? 'Pagar en cuotas mensuales' : 'Cobrar en cuotas mensuales' }}</span>
          </div>
          @if (hasPlan()) {
            <div class="plan" formGroupName="plan">
              <div class="two">
                <ui-field label="Cuota mensual" for="plan-installment" [error]="planError('installment')">
                  <ui-money-input inputId="plan-installment" appearance="field" formControlName="installment" ariaLabel="Cuota mensual" />
                </ui-field>
                <ui-field label="Número de cuotas" for="plan-count" [error]="planError('count')">
                  <input ui-input id="plan-count" type="number" min="1" max="600" inputmode="numeric" formControlName="count" />
                </ui-field>
              </div>
              <ui-field label="Primera cuota">
                <ui-date-picker formControlName="first_payment_date" ariaLabel="Fecha de la primera cuota" />
              </ui-field>
              <div class="two">
                <ui-field label="Cuenta" for="plan-account" [error]="planError('account_id')">
                  <ui-select inputId="plan-account" [options]="accounts()" formControlName="account_id" placeholder="Elige una cuenta" />
                </ui-field>
                @if (direction() === 'i_owe') {
                  <ui-field label="Categoría" for="plan-category">
                    <ui-select inputId="plan-category" [options]="categories()" formControlName="category_id" placeholder="Sin categoría" />
                  </ui-field>
                }
              </div>
              <p class="small muted">Creamos un recurrente mensual con la cuota; cada cargo se descuenta de la deuda.</p>
            </div>
          }
        }

        <ui-field label="Notas" for="debt-notes">
          <textarea ui-textarea id="debt-notes" rows="2" formControlName="notes" placeholder="Opcional"></textarea>
        </ui-field>

        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
      </form>
      <div dialog-footer class="footer">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="debt-form" variant="primary" [loading]="saving()">
          {{ debt ? 'Guardar' : 'Crear deuda' }}
        </button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .form,
    .plan {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .plan {
      padding: 16px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
    }
    .center-self {
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
      align-items: end;
    }
    .toggle {
      display: flex;
      align-items: center;
      gap: 10px;
      min-height: 44px;
    }
    .footer {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
    @media (max-width: 640px) {
      .two {
        grid-template-columns: minmax(0, 1fr);
      }
    }
  `,
})
export class DebtDialog implements OnInit {
  protected readonly ref = inject<DialogRef<Debt>>(DialogRef);
  private readonly data = inject<DebtDialogData>(DIALOG_DATA);
  private readonly debts = inject(DebtsService);
  private readonly contacts = inject(ContactsService);
  private readonly toast = inject(ToastService);

  protected readonly debt = this.data.debt;
  protected readonly canPlan = !this.debt?.recurring_rule_id;
  protected readonly newContact = NEW_CONTACT;
  protected readonly directionOptions = DIRECTION_OPTIONS;

  protected readonly form = new FormGroup({
    direction: new FormControl<DebtDirection>(this.debt?.direction ?? this.data.direction ?? 'i_owe', { nonNullable: true }),
    principal: new FormControl<number | null>(this.debt?.principal_cents ?? null, [Validators.required, Validators.min(1)]),
    name: new FormControl(this.debt?.name ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    contact: new FormControl<string>(this.debt?.contact_id ?? this.data.contactId ?? NO_CONTACT, { nonNullable: true }),
    contact_name: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(120)] }),
    start_date: new FormControl<IsoDate | null>(this.debt?.start_date ?? todayIso(), Validators.required),
    has_due: new FormControl(!!this.debt?.due_date, { nonNullable: true }),
    due_date: new FormControl<IsoDate | null>(this.debt?.due_date ?? addMonths(todayIso(), 1)),
    notes: new FormControl(this.debt?.notes ?? '', { nonNullable: true }),
    has_plan: new FormControl(false, { nonNullable: true }),
    plan: new FormGroup({
      installment: new FormControl<number | null>(null),
      count: new FormControl<number | null>(12),
      first_payment_date: new FormControl<IsoDate | null>(addMonths(todayIso(), 1)),
      account_id: new FormControl<string | null>(null),
      category_id: new FormControl<string | null>(null),
    }),
  });

  private readonly contactList = signal<{ id: string; name: string }[]>([]);
  private readonly accountLookups = signal<FinanceAccountLookup[]>([]);
  private readonly categoryLookups = signal<FinanceCategoryLookup[]>([]);
  protected readonly direction = toSignal(this.form.controls.direction.valueChanges, { initialValue: this.form.controls.direction.value });
  protected readonly contact = toSignal(this.form.controls.contact.valueChanges, { initialValue: this.form.controls.contact.value });
  protected readonly hasDue = toSignal(this.form.controls.has_due.valueChanges, { initialValue: this.form.controls.has_due.value });
  protected readonly hasPlan = toSignal(this.form.controls.has_plan.valueChanges, { initialValue: this.form.controls.has_plan.value });
  protected readonly startDate = toSignal(this.form.controls.start_date.valueChanges, { initialValue: this.form.controls.start_date.value });
  private readonly status = toSignal(this.form.statusChanges, { initialValue: this.form.status });
  protected readonly submitted = signal(false);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly contactOptions = computed<UiSelectOption<string>[]>(() => [
    { value: NO_CONTACT, label: 'Sin contacto', icon: 'user' },
    ...this.contactList().map((contact) => ({ value: contact.id, label: contact.name, icon: 'user' })),
    { value: NEW_CONTACT, label: 'Nuevo contacto…', icon: 'user-plus' },
  ]);
  protected readonly accounts = computed(() => accountOptions(this.accountLookups()));
  protected readonly categories = computed(() => [
    { value: null, label: 'Sin categoría', icon: 'circle' },
    ...categoryOptions(this.categoryLookups(), 'expense'),
  ]);
  protected readonly contactNameError = computed(() => {
    this.status();
    return this.submitted() && !this.form.controls.contact_name.value.trim() ? 'Escribe el nombre.' : null;
  });

  async ngOnInit(): Promise<void> {
    if (!this.contacts.loaded()) {
      await this.contacts.load();
    }
    this.contactList.set(this.contacts.contacts());
    if (!this.canPlan) {
      return;
    }
    const [accounts, categories] = await Promise.all([
      this.debts.accounts().catch(() => []),
      this.debts.categories().catch(() => []),
    ]);
    this.accountLookups.set(accounts);
    this.categoryLookups.set(categories);
    this.form.controls.plan.controls.account_id.setValue(preferredAccountId(accounts));
  }

  protected showError(name: 'principal' | 'name'): boolean {
    this.status();
    const control = this.form.controls[name];
    return control.invalid && (this.submitted() || control.touched);
  }

  protected planError(name: 'installment' | 'count' | 'account_id'): string | null {
    this.status();
    if (!this.submitted() || !this.hasPlan()) {
      return null;
    }
    const value = this.form.controls.plan.controls[name].value;
    if (name === 'account_id') {
      return value ? null : 'Elige una cuenta.';
    }
    return typeof value === 'number' && value > 0 ? null : 'Obligatorio.';
  }

  async save(): Promise<void> {
    this.submitted.set(true);
    this.form.markAllAsTouched();
    const value = this.form.getRawValue();
    const plan = value.plan;
    const planInvalid = value.has_plan && (!plan.installment || !plan.count || plan.count < 1 || !plan.account_id || !plan.first_payment_date);
    const contactInvalid = value.contact === NEW_CONTACT && !value.contact_name.trim();
    if (this.form.invalid || planInvalid || contactInvalid) {
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      const contactId = await this.resolveContact(value.contact, value.contact_name);
      const payload: DebtPayload = {
        name: value.name.trim(),
        direction: value.direction,
        principal_cents: value.principal!,
        start_date: value.start_date!,
        contact_id: contactId,
        due_date: value.has_due ? value.due_date : null,
        notes: value.notes.trim() || null,
      };
      if (value.has_plan && this.canPlan) {
        payload.plan = {
          account_id: plan.account_id!,
          installment_cents: plan.installment!,
          installments_count: plan.count!,
          first_payment_date: plan.first_payment_date!,
          category_id: value.direction === 'i_owe' ? plan.category_id : null,
        };
      }
      const saved = this.debt ? await this.debts.update(this.debt.id, payload) : await this.debts.create(payload);
      this.toast.show(this.debt ? 'Deuda actualizada' : 'Deuda creada');
      this.ref.close(saved);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar la deuda.'));
    } finally {
      this.saving.set(false);
    }
  }

  private async resolveContact(choice: string, name: string): Promise<string | null> {
    if (choice === NO_CONTACT) {
      return null;
    }
    if (choice !== NEW_CONTACT) {
      return choice;
    }
    const created = await this.contacts.create({ name: name.trim(), notes: null });
    this.contactList.update((list) => [...list, created]);
    this.form.controls.contact.setValue(created.id);
    return created.id;
  }
}
