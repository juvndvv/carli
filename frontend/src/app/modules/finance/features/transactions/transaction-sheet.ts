import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import {
  afterNextRender,
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  signal,
  untracked,
  viewChild,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormArray, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { todayIso } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiButton } from '@ui/button/button';
import { UiCategoryOption, UiCategoryPicker } from '@ui/category-picker/category-picker';
import { UiChip } from '@ui/chip/chip';
import { UiCombobox } from '@ui/combobox/combobox';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiIcon } from '@ui/icon/icon';
import { UiInput } from '@ui/input/input';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSwitch } from '@ui/switch/switch';
import { UiTextarea } from '@ui/textarea/textarea';
import { ToastService } from '@ui/toast/toast.service';
import { map } from 'rxjs';
import { AccountsService } from '../../data-access/accounts.service';
import { CategoriesService, CategoryEntry } from '../../data-access/categories.service';
import { ContactOptionsService } from '../../data-access/contact-options.service';
import { FinanceSettingsService } from '../../data-access/finance-settings.service';
import {
  ACCOUNT_TYPE_ICONS,
  CategoryKind,
  PayeeSuggestion,
  ShareMode,
  Transaction,
  TransactionInput,
} from '../../data-access/finance.models';
import { PayeesService } from '../../data-access/payees.service';
import { RecentCategories } from '../../data-access/recent-categories';
import { TagsService } from '../../data-access/tags.service';
import { TransactionsService } from '../../data-access/transactions.service';
import { registerFinanceIcons } from '../../ui/finance-icons';
import {
  EntryKind,
  parseTagInput,
  previewShares,
  SharePreviewItem,
  signedAmount,
  splitRemaining,
  toSharesInput,
  toSplitInputs,
  TransactionSheetData,
  TransactionSheetResult,
} from './transaction-form';

const QUICK_CATEGORY_COUNT = 7;

type ShareGroup = FormGroup<{
  contactId: FormControl<string>;
  percentage: FormControl<number | null>;
  amount: FormControl<number | null>;
}>;

type SplitGroup = FormGroup<{
  categoryId: FormControl<string | null>;
  amount: FormControl<number | null>;
}>;

let nextSheetId = 0;

function withPeriodsNotice(message: string, periodsChanged: boolean): string {
  return periodsChanged ? `${message} · periodos recalculados` : message;
}

@Component({
  selector: 'fin-transaction-sheet',
  imports: [
    ReactiveFormsModule,
    MoneyPipe,
    UiDialog,
    UiButton,
    UiSegmented,
    UiMoneyInput,
    UiCategoryPicker,
    UiSelect,
    UiDatePicker,
    UiCombobox,
    UiField,
    UiInput,
    UiTextarea,
    UiSwitch,
    UiChip,
    UiIcon,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="heading()">
      @if (editing()) {
          <span dialog-actions class="row head-actions">
            <button
              ui-button
              type="button"
              variant="ghost"
              size="sm"
              icon="copy"
              iconOnly
              aria-label="Duplicar movimiento"
              (click)="duplicate()"
            ></button>
            <button
              ui-button
              type="button"
              variant="ghost"
              size="sm"
              icon="trash"
              iconOnly
              aria-label="Eliminar movimiento"
              [loading]="deleting()"
              (click)="remove()"
            ></button>
          </span>
      }
      <form class="stack" [formGroup]="form" (ngSubmit)="save()" novalidate>
        <ui-segmented formControlName="kind" ariaLabel="Tipo de movimiento" [options]="kindOptions()" />

        <ui-money-input
          #amountInput
          formControlName="amount"
          ariaLabel="Importe"
          [focusInitial]="!editing()"
          [sign]="amountSign()"
          [allowNegative]="kind() === 'adjustment'"
        />
        @if (submitted() && form.controls.amount.invalid) {
          <span class="field-error center" role="alert">Introduce un importe mayor que 0.</span>
        }

        @if (kind() === 'transfer') {
          <div class="grid-cards g-2">
            <ui-field label="Desde" [for]="ids.from">
              <ui-select
                formControlName="accountId"
                placeholder="Cuenta de origen"
                [inputId]="ids.from"
                [options]="accountOptions()"
              />
            </ui-field>
            <ui-field
              label="Hacia"
              [for]="ids.to"
              [error]="submitted() && transferError() ? transferError() : null"
            >
              <ui-select
                formControlName="toAccountId"
                placeholder="Cuenta de destino"
                [inputId]="ids.to"
                [options]="accountOptions()"
              />
            </ui-field>
          </div>
        } @else {
          @if (kind() !== 'adjustment' && !form.controls.splitEnabled.value) {
            <div class="field">
              <span class="field-label" [id]="ids.category">Categoría</span>
              <ui-category-picker
                formControlName="categoryId"
                [attr.aria-labelledby]="ids.category"
                [categories]="categoryOptions()"
                (click)="categoryTouched.set(true)"
              />
              <div class="row between category-tools">
                @if (suggestion(); as suggested) {
                  <span class="small faint suggestion">
                    <ui-icon name="sparkles" [size]="13" /> Sugerida: {{ suggested }} (por usos anteriores)
                  </span>
                } @else {
                  <span></span>
                }
                @if (hasMoreCategories()) {
                  <button ui-button type="button" variant="ghost" size="sm" (click)="showAllCategories.set(!showAllCategories())">
                    {{ showAllCategories() ? 'Ver menos' : 'Ver todas' }}
                  </button>
                }
              </div>
            </div>
          }
          <div class="grid-cards g-2">
            <ui-field label="Cuenta" [for]="ids.account" [error]="submitted() && form.controls.accountId.invalid ? 'Elige una cuenta.' : null">
              <ui-select
                formControlName="accountId"
                placeholder="Elige una cuenta"
                [inputId]="ids.account"
                [options]="accountOptions()"
              />
            </ui-field>
            <div class="field">
              <span class="field-label" [id]="ids.date">Fecha</span>
              <ui-date-picker formControlName="date" [attr.aria-labelledby]="ids.date" />
            </div>
          </div>
          @if (kind() !== 'adjustment') {
            <ui-field [label]="kind() === 'income' ? 'Pagador o concepto' : 'Comercio o concepto'" [for]="ids.payee">
              <ui-combobox
                formControlName="payee"
                allowCustom
                [filterLocally]="false"
                [inputId]="ids.payee"
                [placeholder]="kind() === 'income' ? 'Ej. Acme S.L.' : 'Ej. Mercadona'"
                [options]="payeeOptions()"
                (query)="searchPayees($event)"
                (optionSelected)="applySuggestion($event.value)"
              />
            </ui-field>
          }
        }

        @if (kind() === 'transfer') {
          <div class="field">
            <span class="field-label" [id]="ids.date">Fecha</span>
            <ui-date-picker formControlName="date" [attr.aria-labelledby]="ids.date" />
          </div>
        }

        <button type="button" class="more" [attr.aria-expanded]="showMore()" (click)="showMore.set(!showMore())">
          <ui-icon [name]="showMore() ? 'chevron-up' : 'chevron-down'" [size]="16" />
          {{ moreLabel() }}
        </button>

        @if (showMore()) {
          <div class="stack">
            <ui-field label="Concepto" [for]="ids.description">
              <input ui-input formControlName="description" [id]="ids.description" placeholder="Opcional" />
            </ui-field>

            <div class="field">
              <label class="field-label" [for]="ids.tags">Etiquetas</label>
              <div class="row wrap tags">
                @for (tag of tags(); track tag) {
                  <button ui-chip type="button" selected trailingIcon="x" [pressable]="false" [attr.aria-label]="'Quitar #' + tag" (click)="removeTag(tag)">
                    #{{ tag }}
                  </button>
                }
                <input
                  ui-input
                  class="tag-input"
                  [id]="ids.tags"
                  [attr.list]="ids.tags + '-list'"
                  placeholder="Añadir etiqueta"
                  enterkeyhint="done"
                  autocomplete="off"
                  [formControl]="tagDraft"
                  (keydown.enter)="$event.preventDefault(); addTags()"
                  (keydown.comma)="$event.preventDefault(); addTags()"
                  (blur)="addTags()"
                />
                <datalist [id]="ids.tags + '-list'">
                  @for (name of tagSuggestions(); track name) {
                    <option [value]="name"></option>
                  }
                </datalist>
              </div>
            </div>

            <ui-field label="Nota" [for]="ids.notes">
              <textarea ui-textarea formControlName="notes" rows="3" [id]="ids.notes"></textarea>
            </ui-field>

            <div class="row between">
              <span>Pendiente de confirmar</span>
              <ui-switch formControlName="pending" label="Pendiente de confirmar" />
            </div>

            @if (kind() === 'expense') {
              <div class="row between">
                <span>Gasto compartido</span>
                <ui-switch formControlName="shareEnabled" label="Gasto compartido" />
              </div>
              @if (form.controls.shareEnabled.value) {
                <div class="panel stack">
                  @if (sharesLocked()) {
                    <p class="small muted">Este gasto ya tiene partes liquidadas y no se puede cambiar el reparto.</p>
                    <div class="ui-list">
                      @for (share of original()?.shares ?? []; track share.id) {
                        <div class="row between share-line small">
                          <span>{{ share.name }}{{ share.settled ? ' · liquidado' : '' }}</span>
                          <span class="num">{{ share.amount_cents | money }}</span>
                        </div>
                      }
                    </div>
                  } @else if (contacts.active().length === 0) {
                    <p class="small muted">Aún no tienes contactos. Créalos en Compartidos para repartir gastos.</p>
                  } @else {
                    <ui-segmented formControlName="shareMode" ariaLabel="Forma de reparto" [options]="shareModeOptions" />
                    <div class="row wrap chips" role="group" aria-label="Con quién lo compartes">
                      @for (contact of contacts.active(); track contact.id) {
                        <button ui-chip type="button" [selected]="isSharedWith(contact.id)" (click)="toggleShare(contact.id)">
                          {{ contact.name }}
                        </button>
                      }
                    </div>
                    @if (form.controls.shareMode.value === 'equal') {
                      <div class="row between small">
                        <span class="muted">Incluirme en el reparto</span>
                        <ui-switch formControlName="includeSelf" label="Incluirme en el reparto" />
                      </div>
                    }
                    <div formArrayName="shares" class="stack share-items">
                      @for (group of form.controls.shares.controls; track group.controls.contactId.value; let index = $index) {
                        <div class="row between share-line" [formGroupName]="index">
                          <span class="share-name">{{ contactName(group.controls.contactId.value) }}</span>
                          @if (form.controls.shareMode.value === 'percentage') {
                            <span class="row percent">
                              <input
                                ui-input
                                type="number"
                                inputmode="decimal"
                                min="0"
                                max="100"
                                step="0.01"
                                formControlName="percentage"
                                [attr.aria-label]="'Porcentaje de ' + contactName(group.controls.contactId.value)"
                              />
                              <span class="faint">%</span>
                            </span>
                          } @else if (form.controls.shareMode.value === 'amount') {
                            <ui-money-input
                              class="share-amount"
                              appearance="field"
                              formControlName="amount"
                              [ariaLabel]="'Parte de ' + contactName(group.controls.contactId.value)"
                            />
                          }
                          <span class="num small preview">{{ sharePreview()[index]?.amount ?? 0 | money }}</span>
                        </div>
                      }
                    </div>
                    @if (shareSummary(); as summary) {
                      <p class="small" [class.neg]="shareOverflow()">{{ summary }}</p>
                    }
                  }
                </div>
              }
            }

            @if (kind() === 'expense' || kind() === 'income') {
              <div class="row between">
                <span>Dividir en varias categorías</span>
                <ui-switch formControlName="splitEnabled" label="Dividir en varias categorías" />
              </div>
              @if (form.controls.splitEnabled.value) {
                <div class="panel stack" formArrayName="splits">
                  @for (group of form.controls.splits.controls; track group; let index = $index) {
                    <div class="split-line" [formGroupName]="index">
                      <ui-select
                        formControlName="categoryId"
                        placeholder="Categoría"
                        [ariaLabel]="'Categoría de la parte ' + (index + 1)"
                        [options]="allCategoryOptions()"
                      />
                      <ui-money-input appearance="field" formControlName="amount" [ariaLabel]="'Importe de la parte ' + (index + 1)" />
                      <button
                        ui-button
                        type="button"
                        variant="ghost"
                        size="sm"
                        icon="x"
                        iconOnly
                        [attr.aria-label]="'Quitar parte ' + (index + 1)"
                        (click)="removeSplit(index)"
                      ></button>
                    </div>
                  }
                  <div class="row between">
                    <button ui-button type="button" variant="ghost" size="sm" icon="plus" (click)="addSplit()">Añadir parte</button>
                    <span class="small" [class.neg]="splitLeft() !== 0" [class.muted]="splitLeft() === 0">
                      @if (splitLeft() === 0) {
                        Reparto completo
                      } @else if (splitLeft() > 0) {
                        Quedan {{ splitLeft() | money }} por asignar
                      } @else {
                        Te pasas en {{ -splitLeft() | money }}
                      }
                    </span>
                  </div>
                </div>
              }
            }
          </div>
        }

        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }

        <div class="submit-bar">
          <button ui-button type="submit" variant="primary" size="lg" block [loading]="saving()">Guardar</button>
        </div>
      </form>
    </ui-dialog>
  `,
  styles: `
    :host {
      display: block;
    }
    .center {
      text-align: center;
      margin-top: -12px;
    }
    .head-actions {
      gap: 0;
    }
    .submit-bar {
      position: sticky;
      bottom: 0;
      z-index: 1;
      margin-top: -8px;
      padding: 8px 0 12px;
      background: var(--surface);
    }
    .category-tools {
      min-height: 32px;
    }
    .suggestion ui-icon {
      vertical-align: -2px;
    }
    .more {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      align-self: flex-start;
      border: 0;
      background: none;
      padding: 4px 0;
      font-size: 13px;
      font-weight: 550;
      color: var(--text);
    }
    .tags {
      gap: 6px;
    }
    .tag-input {
      flex: 1;
      min-width: 140px;
      height: 32px;
      border-radius: var(--r-full);
    }
    .panel {
      background: var(--surface-2);
      border-radius: var(--r-md);
      padding: 12px;
      gap: 12px;
    }
    .chips {
      gap: 6px;
    }
    .share-line {
      gap: 8px;
      min-height: 36px;
    }
    .share-name {
      flex: 1;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .percent {
      gap: 6px;
      width: 110px;
    }
    .percent input {
      height: 36px;
    }
    .share-amount {
      width: 130px;
      height: 36px;
    }
    .preview {
      min-width: 80px;
      text-align: right;
    }
    .split-line {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 130px 32px;
      gap: 8px;
      align-items: center;
    }
  `,
})
export class TransactionSheet {
  private readonly data = inject<TransactionSheetData | null>(DIALOG_DATA, { optional: true }) ?? {};
  private readonly ref = inject<DialogRef<TransactionSheetResult>>(DialogRef);
  private readonly transactions = inject(TransactionsService);
  private readonly accounts = inject(AccountsService);
  private readonly categories = inject(CategoriesService);
  private readonly settings = inject(FinanceSettingsService);
  private readonly payees = inject(PayeesService);
  private readonly tagsService = inject(TagsService);
  private readonly recents = inject(RecentCategories);
  private readonly toast = inject(ToastService);
  protected readonly contacts = inject(ContactOptionsService);
  private readonly amountInput = viewChild<UiMoneyInput>('amountInput');

  protected readonly ids = (() => {
    const prefix = `fin-tx-${nextSheetId++}`;
    return {
      from: `${prefix}-from`,
      to: `${prefix}-to`,
      category: `${prefix}-category`,
      account: `${prefix}-account`,
      date: `${prefix}-date`,
      payee: `${prefix}-payee`,
      description: `${prefix}-description`,
      tags: `${prefix}-tags`,
      notes: `${prefix}-notes`,
    };
  })();

  protected readonly original = signal<Transaction | null>(this.data.transaction ?? null);
  protected readonly editing = computed(() => this.original() !== null);
  protected readonly saving = signal(false);
  protected readonly deleting = signal(false);
  protected readonly submitted = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly showMore = signal(false);
  protected readonly showAllCategories = signal(false);
  protected readonly categoryTouched = signal(false);
  protected readonly suggestions = signal<PayeeSuggestion[]>([]);
  protected readonly suggestion = signal<string | null>(null);
  private accountTouched = false;
  private sharesDirty = false;
  private splitsDirty = false;
  private payeeTimer: ReturnType<typeof setTimeout> | null = null;

  protected readonly form = new FormGroup({
    kind: new FormControl<EntryKind>('expense', { nonNullable: true }),
    amount: new FormControl<number | null>(null, [Validators.required, Validators.min(1)]),
    categoryId: new FormControl<string | null>(null),
    accountId: new FormControl<string | null>(null, Validators.required),
    toAccountId: new FormControl<string | null>(null),
    date: new FormControl<string>(todayIso(), { nonNullable: true }),
    payee: new FormControl<string | null>(null),
    description: new FormControl<string>('', { nonNullable: true }),
    notes: new FormControl<string>('', { nonNullable: true }),
    pending: new FormControl<boolean>(false, { nonNullable: true }),
    tags: new FormControl<string[]>([], { nonNullable: true }),
    shareEnabled: new FormControl<boolean>(false, { nonNullable: true }),
    shareMode: new FormControl<ShareMode>('equal', { nonNullable: true }),
    includeSelf: new FormControl<boolean>(true, { nonNullable: true }),
    shares: new FormArray<ShareGroup>([]),
    splitEnabled: new FormControl<boolean>(false, { nonNullable: true }),
    splits: new FormArray<SplitGroup>([]),
  });

  protected readonly tagDraft = new FormControl('', { nonNullable: true });

  private readonly value = toSignal(this.form.valueChanges.pipe(map(() => this.form.getRawValue())), {
    initialValue: this.form.getRawValue(),
  });

  protected readonly kind = computed(() => this.value().kind);
  protected readonly tags = computed(() => this.value().tags);
  protected readonly heading = computed(() => {
    if (!this.editing()) {
      return 'Nuevo movimiento';
    }
    return this.kind() === 'transfer' ? 'Editar transferencia' : 'Editar movimiento';
  });
  protected readonly amountSign = computed(() =>
    this.kind() === 'expense' ? 'negative' : this.kind() === 'income' ? 'positive' : 'none',
  );
  protected readonly kindOptions = computed<UiSegmentedOption<EntryKind>[]>(() => {
    const original = this.original();
    if (original?.kind === 'transfer') {
      return [{ value: 'transfer', label: 'Transferencia' }];
    }
    if (original?.kind === 'adjustment') {
      return [{ value: 'adjustment', label: 'Ajuste' }];
    }
    const options: UiSegmentedOption<EntryKind>[] = [
      { value: 'expense', label: 'Gasto' },
      { value: 'income', label: 'Ingreso' },
    ];
    return original ? options : [...options, { value: 'transfer', label: 'Transferencia' }];
  });
  protected readonly shareModeOptions: UiSegmentedOption<ShareMode>[] = [
    { value: 'equal', label: 'A partes iguales' },
    { value: 'percentage', label: 'Porcentaje' },
    { value: 'amount', label: 'Importe' },
  ];
  protected readonly moreLabel = computed(() =>
    this.kind() === 'expense'
      ? 'Más opciones: etiquetas, nota, compartir, dividir'
      : this.kind() === 'income'
        ? 'Más opciones: etiquetas, nota, dividir'
        : 'Más opciones: concepto, etiquetas, nota',
  );

  protected readonly accountOptions = computed<UiSelectOption<string>[]>(() => {
    const current = [this.original()?.account_id, this.original()?.transfer_account_id];
    return this.accounts
      .all()
      .filter((account) => !account.archived || current.includes(account.id))
      .map((account) => ({ value: account.id, label: account.name, icon: account.icon ?? ACCOUNT_TYPE_ICONS[account.type] }));
  });

  private readonly categoryKind = computed<CategoryKind>(() => (this.kind() === 'income' ? 'income' : 'expense'));
  private readonly selectableCategories = computed(() => this.categories.selectable(this.categoryKind()));
  protected readonly hasMoreCategories = computed(() => this.selectableCategories().length > QUICK_CATEGORY_COUNT + 1);
  protected readonly categoryOptions = computed<UiCategoryOption[]>(() => {
    const entries = this.selectableCategories();
    if (this.showAllCategories() || !this.hasMoreCategories()) {
      return entries.map(toPickerOption);
    }
    const byId = new Map(entries.map((entry) => [entry.category.id, entry]));
    const chosen: CategoryEntry[] = [];
    const push = (entry: CategoryEntry | undefined) => {
      if (entry && !chosen.includes(entry)) {
        chosen.push(entry);
      }
    };
    this.recents.ids(this.categoryKind()).forEach((id) => push(byId.get(id)));
    entries.filter((entry) => entry.parent === null).forEach(push);
    entries.forEach(push);
    const quick = chosen.slice(0, QUICK_CATEGORY_COUNT + 1);
    const selected = byId.get(this.value().categoryId ?? '');
    if (selected && !quick.includes(selected)) {
      quick[quick.length - 1] = selected;
    }
    return quick.map(toPickerOption);
  });
  protected readonly allCategoryOptions = computed<UiSelectOption<string>[]>(() =>
    this.selectableCategories().map((entry) => ({ value: entry.category.id, label: entry.label, icon: entry.icon })),
  );
  protected readonly payeeOptions = computed<UiSelectOption<string>[]>(() =>
    this.suggestions().map((item) => ({
      value: item.payee,
      label: item.payee,
      description: item.category ? item.category.name : null,
    })),
  );
  protected readonly tagSuggestions = computed(() => this.tagsService.names().filter((name) => !this.tags().includes(name)));

  protected readonly sharesLocked = computed(() => this.original()?.shares.some((share) => share.settled) ?? false);
  private readonly shareItems = computed<SharePreviewItem[]>(() =>
    this.value().shares.map((share) => ({
      contactId: share.contactId,
      name: this.contactName(share.contactId),
      percentage: share.percentage,
      amount: share.amount,
    })),
  );
  protected readonly sharePreview = computed(() =>
    previewShares(this.value().amount ?? 0, this.value().shareMode, this.value().includeSelf, this.shareItems()),
  );
  private readonly sharedTotal = computed(() => this.sharePreview().reduce((sum, item) => sum + item.amount, 0));
  protected readonly shareOverflow = computed(() => this.sharedTotal() > Math.abs(this.value().amount ?? 0));
  protected readonly shareSummary = computed(() => {
    const preview = this.sharePreview();
    if (preview.length === 0) {
      return null;
    }
    if (this.shareOverflow()) {
      return 'La parte compartida supera el importe del gasto.';
    }
    const own = Math.abs(this.value().amount ?? 0) - this.sharedTotal();
    if (preview.length === 1) {
      return `${preview[0].name} te debe ${formatMoney(preview[0].amount)} · tu parte ${formatMoney(own)}`;
    }
    return `Te deben ${formatMoney(this.sharedTotal())} · tu parte ${formatMoney(own)}`;
  });
  protected readonly splitLeft = computed(() => splitRemaining(this.value().amount ?? 0, this.value().splits));
  protected readonly transferError = computed(() => {
    const { accountId, toAccountId } = this.value();
    if (!toAccountId) {
      return 'Elige la cuenta de destino.';
    }
    return toAccountId === accountId ? 'Elige dos cuentas distintas.' : null;
  });

  constructor() {
    registerFinanceIcons();
    this.initialise();

    effect(() => {
      const preferred = this.settings.preferredAccountId();
      const active = this.accounts.active();
      untracked(() => {
        if (this.accountTouched || this.editing() || this.form.controls.accountId.value) {
          return;
        }
        const fallback = active.find((account) => account.id === preferred)?.id ?? active[0]?.id ?? null;
        if (fallback) {
          this.form.controls.accountId.setValue(fallback, { emitEvent: true });
        }
      });
    });

    effect(() => {
      const active = this.accounts.active();
      untracked(() => {
        if (this.kind() !== 'transfer' || this.form.controls.toAccountId.value) {
          return;
        }
        const target = active.find((account) => account.id !== this.form.controls.accountId.value);
        if (target) {
          this.form.controls.toAccountId.setValue(target.id);
        }
      });
    });

    this.form.controls.accountId.valueChanges.subscribe(() => {
      if (this.form.controls.accountId.dirty) {
        this.accountTouched = true;
      }
    });
    this.form.controls.kind.valueChanges.subscribe((kind) => this.onKindChange(kind));
    this.form.controls.splitEnabled.valueChanges.subscribe((enabled) => {
      this.splitsDirty = true;
      if (enabled && this.form.controls.splits.length === 0) {
        this.addSplit(this.form.controls.categoryId.value, this.form.controls.amount.value);
        this.addSplit();
      }
    });
    this.form.controls.shareEnabled.valueChanges.subscribe(() => (this.sharesDirty = true));
    this.form.controls.shareMode.valueChanges.subscribe(() => (this.sharesDirty = true));
    this.form.controls.includeSelf.valueChanges.subscribe(() => (this.sharesDirty = true));
    this.form.controls.shares.valueChanges.subscribe(() => (this.sharesDirty = true));
    this.form.controls.splits.valueChanges.subscribe(() => (this.splitsDirty = true));

    afterNextRender(() => {
      if (!this.editing()) {
        this.amountInput()?.focus();
      }
    });
  }

  protected contactName(id: string): string {
    return this.contacts.find(id)?.name ?? this.original()?.shares.find((share) => share.contact_id === id)?.name ?? 'Contacto';
  }

  protected isSharedWith(contactId: string): boolean {
    return this.value().shares.some((share) => share.contactId === contactId);
  }

  protected toggleShare(contactId: string): void {
    const shares = this.form.controls.shares;
    const index = shares.controls.findIndex((group) => group.controls.contactId.value === contactId);
    if (index >= 0) {
      shares.removeAt(index);
      return;
    }
    shares.push(shareGroup(contactId, shares.length === 0 ? 50 : null, null));
  }

  protected addSplit(categoryId: string | null = null, amount: number | null = null): void {
    this.form.controls.splits.push(
      new FormGroup({
        categoryId: new FormControl<string | null>(categoryId),
        amount: new FormControl<number | null>(amount),
      }),
    );
  }

  protected removeSplit(index: number): void {
    this.form.controls.splits.removeAt(index);
    if (this.form.controls.splits.length === 0) {
      this.form.controls.splitEnabled.setValue(false);
    }
  }

  protected addTags(): void {
    const additions = parseTagInput(this.tagDraft.value);
    this.tagDraft.setValue('');
    if (additions.length === 0) {
      return;
    }
    const current = this.form.controls.tags.value;
    this.form.controls.tags.setValue([...new Set([...current, ...additions])]);
  }

  protected removeTag(tag: string): void {
    this.form.controls.tags.setValue(this.form.controls.tags.value.filter((item) => item !== tag));
  }

  protected searchPayees(query: string): void {
    if (this.payeeTimer) {
      clearTimeout(this.payeeTimer);
    }
    this.suggestion.set(null);
    if (query.trim().length < 2) {
      this.suggestions.set([]);
      return;
    }
    this.payeeTimer = setTimeout(async () => {
      try {
        this.suggestions.set(await this.payees.suggest(query, this.categoryKind()));
      } catch {
        this.suggestions.set([]);
      }
    }, 200);
  }

  protected applySuggestion(payee: string): void {
    const match = this.suggestions().find((item) => item.payee === payee);
    const category = match?.category;
    if (!category || category.kind !== this.categoryKind()) {
      return;
    }
    if (!this.categoryTouched() || !this.form.controls.categoryId.value) {
      this.form.controls.categoryId.setValue(category.id);
      this.suggestion.set(category.name);
    }
  }

  protected async save(): Promise<void> {
    this.submitted.set(true);
    this.error.set(null);
    const raw = this.form.getRawValue();
    if (this.form.controls.amount.invalid && raw.kind !== 'adjustment') {
      return;
    }
    if (!raw.amount) {
      return;
    }
    if (raw.kind === 'transfer') {
      if (!this.editing() && this.transferError()) {
        return;
      }
    } else if (!raw.accountId) {
      return;
    }
    if (raw.kind !== 'transfer' && raw.splitEnabled && this.splitLeft() !== 0) {
      this.error.set('El reparto entre categorías debe sumar el importe total.');
      return;
    }
    if (raw.kind === 'expense' && raw.shareEnabled && this.shareOverflow()) {
      this.error.set('La parte compartida supera el importe del gasto.');
      return;
    }

    this.saving.set(true);
    try {
      const saved = raw.kind === 'transfer' ? await this.saveTransfer() : await this.saveEntry();
      this.ref.close({ action: 'saved', transaction: saved.transaction });
      this.announce(saved.transaction, saved.periodsChanged, saved.created);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar el movimiento.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected duplicate(): void {
    const original = this.original();
    if (original) {
      this.ref.close({ action: 'duplicate', transaction: original });
    }
  }

  protected async remove(): Promise<void> {
    const original = this.original();
    if (!original) {
      return;
    }
    this.deleting.set(true);
    try {
      const periodsChanged = await this.transactions.remove(original.id);
      this.ref.close({ action: 'deleted', transaction: original });
      const base = original.kind === 'transfer' ? 'Transferencia eliminada' : 'Movimiento eliminado';
      this.toast.withUndo(withPeriodsNotice(base, periodsChanged), () => this.undoRemove(original.id));
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido eliminar el movimiento.'));
    } finally {
      this.deleting.set(false);
    }
  }

  private async saveTransfer(): Promise<{ transaction: Transaction; periodsChanged: boolean; created: boolean }> {
    const raw = this.form.getRawValue();
    const original = this.original();
    const common = {
      amount_cents: Math.abs(raw.amount ?? 0),
      date: raw.date,
      description: raw.description.trim() || null,
      notes: raw.notes.trim() || null,
      status: raw.pending ? ('pending' as const) : ('cleared' as const),
      tags: raw.tags,
    };
    if (original) {
      const result = await this.transactions.update(original.id, common);
      return { ...result, created: false };
    }
    const result = await this.transactions.transfer({
      ...common,
      from_account_id: raw.accountId!,
      to_account_id: raw.toAccountId!,
    });
    return { transaction: result.from, periodsChanged: false, created: true };
  }

  private async saveEntry(): Promise<{ transaction: Transaction; periodsChanged: boolean; created: boolean }> {
    const raw = this.form.getRawValue();
    const original = this.original();
    const kind = raw.kind as Exclude<EntryKind, 'transfer'>;
    const splitting = raw.splitEnabled && kind !== 'adjustment';
    const input: TransactionInput = {
      account_id: raw.accountId!,
      kind,
      amount_cents: signedAmount(kind, raw.amount ?? 0),
      date: raw.date,
      category_id: splitting || kind === 'adjustment' ? null : raw.categoryId,
      payee: kind === 'adjustment' ? (original?.payee ?? null) : raw.payee?.trim() || null,
      description: raw.description.trim() || null,
      notes: raw.notes.trim() || null,
      status: raw.pending ? 'pending' : 'cleared',
      tags: raw.tags,
    };
    if (!original || this.splitsDirty) {
      input.splits = splitting ? toSplitInputs(kind, raw.splits) : original?.splits.length ? null : undefined;
    }
    if (!this.sharesLocked() && (!original || this.sharesDirty)) {
      const sharing = kind === 'expense' && raw.shareEnabled && raw.shares.length > 0;
      input.shares = sharing
        ? toSharesInput(raw.shareMode, raw.includeSelf, this.shareItems())
        : original?.shares.length
          ? null
          : undefined;
    }
    Object.keys(input).forEach((key) => {
      if (input[key as keyof TransactionInput] === undefined) {
        delete input[key as keyof TransactionInput];
      }
    });
    if (raw.categoryId && !splitting && kind !== 'adjustment') {
      this.recents.remember(this.categoryKind(), raw.categoryId);
    }
    const result = original ? await this.transactions.update(original.id, input) : await this.transactions.create(input);
    return { ...result, created: !original };
  }

  private announce(transaction: Transaction, periodsChanged: boolean, created: boolean): void {
    const message = withPeriodsNotice(created ? 'Movimiento guardado' : 'Cambios guardados', periodsChanged);
    if (created) {
      this.toast.withUndo(message, () => this.undoCreate(transaction.id));
    } else {
      this.toast.show(message);
    }
  }

  private async undoRemove(id: string): Promise<void> {
    const { periodsChanged } = await this.transactions.restore(id);
    if (periodsChanged) {
      this.toast.show(withPeriodsNotice('Movimiento restaurado', true));
    }
  }

  private async undoCreate(id: string): Promise<void> {
    if (await this.transactions.remove(id)) {
      this.toast.show(withPeriodsNotice('Movimiento deshecho', true));
    }
  }

  private onKindChange(kind: EntryKind): void {
    const category = this.categories.find(this.form.controls.categoryId.value);
    if (category && category.category.kind !== (kind === 'income' ? 'income' : 'expense')) {
      this.form.controls.categoryId.setValue(null);
    }
    this.suggestion.set(null);
    this.suggestions.set([]);
    if (kind === 'transfer' && !this.form.controls.toAccountId.value) {
      const target = this.accounts.active().find((account) => account.id !== this.form.controls.accountId.value);
      this.form.controls.toAccountId.setValue(target?.id ?? null);
    }
    if (kind !== 'expense') {
      this.form.controls.shareEnabled.setValue(false, { emitEvent: false });
    }
    queueMicrotask(() => this.amountInput()?.focus());
  }

  private initialise(): void {
    const source = this.data.transaction ?? this.data.duplicateOf ?? null;
    const preset = this.data.preset ?? {};
    if (!source) {
      this.form.patchValue({
        kind: preset.kind ?? 'expense',
        accountId: preset.accountId ?? null,
        toAccountId: preset.toAccountId ?? null,
        categoryId: preset.categoryId ?? null,
        date: preset.date ?? todayIso(),
        payee: preset.payee ?? null,
      });
      this.accountTouched = !!preset.accountId;
      return;
    }
    const isTransfer = source.kind === 'transfer';
    const outgoing = !isTransfer || source.amount_cents < 0;
    this.form.patchValue({
      kind: source.kind,
      amount: Math.abs(source.amount_cents),
      categoryId: source.category_id,
      accountId: isTransfer && !outgoing ? source.transfer_account_id : source.account_id,
      toAccountId: isTransfer ? (outgoing ? source.transfer_account_id : source.account_id) : null,
      date: this.data.duplicateOf ? todayIso() : source.date,
      payee: source.payee,
      description: source.description ?? '',
      notes: source.notes ?? '',
      pending: this.data.duplicateOf ? false : source.status === 'pending',
      tags: [...source.tags],
      splitEnabled: source.splits.length > 0,
      shareEnabled: source.shares.length > 0,
      shareMode: 'amount',
    });
    source.splits.forEach((split) => this.addSplit(split.category_id, Math.abs(split.amount_cents)));
    source.shares.forEach((share) =>
      this.form.controls.shares.push(shareGroup(share.contact_id, null, share.amount_cents)),
    );
    this.accountTouched = true;
    this.categoryTouched.set(true);
    this.showMore.set(
      !!source.description || !!source.notes || source.tags.length > 0 || source.splits.length > 0 || source.shares.length > 0,
    );
    if (this.data.transaction && isTransfer) {
      this.form.controls.accountId.disable({ emitEvent: false });
      this.form.controls.toAccountId.disable({ emitEvent: false });
    }
    if (this.data.duplicateOf) {
      this.original.set(null);
      this.sharesDirty = true;
      this.splitsDirty = true;
    }
    if (this.sharesLocked()) {
      this.form.controls.shareEnabled.disable({ emitEvent: false });
    }
  }
}

function shareGroup(contactId: string, percentage: number | null, amount: number | null): ShareGroup {
  return new FormGroup({
    contactId: new FormControl<string>(contactId, { nonNullable: true }),
    percentage: new FormControl<number | null>(percentage),
    amount: new FormControl<number | null>(amount),
  });
}

function toPickerOption(entry: CategoryEntry): UiCategoryOption {
  return { id: entry.category.id, name: entry.category.name, icon: entry.icon };
}
