import { ChangeDetectionStrategy, Component, computed, effect, inject, input, signal, untracked } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormArray, FormControl, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiField } from '@ui/field/field';
import { UiIcon } from '@ui/icon/icon';
import { UiInput } from '@ui/input/input';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ToastService } from '@ui/toast/toast.service';
import { AccountsService } from '../../data-access/accounts.service';
import { BankAccountCandidate, BankAccountLinkInput, BankConnection, maskIban, NEW_ACCOUNT } from '../../data-access/bank.models';
import { BankService } from '../../data-access/bank.service';
import { Account, ACCOUNT_TYPE_ICONS, ACCOUNT_TYPE_LABELS, AccountType } from '../../data-access/finance.models';
import { BANK_SETTINGS_PATH } from './bank-connections-page';

export type LinkTarget = string | null;

type LinkRow = FormGroup<{
  externalUid: FormControl<string>;
  target: FormControl<LinkTarget>;
  name: FormControl<string>;
  type: FormControl<AccountType>;
  from: FormControl<string>;
}>;

export function candidateTitle(candidate: BankAccountCandidate): string {
  return candidate.name?.trim() || ACCOUNT_TYPE_LABELS[candidate.suggested_account_type];
}

export function candidateSubtitle(candidate: BankAccountCandidate): string {
  return [maskIban(candidate.iban), candidate.currency, candidate.linked_account ? `vinculada a ${candidate.linked_account.name}` : null]
    .filter((part): part is string => !!part)
    .join(' · ');
}

export function defaultNewAccountName(bank: string, candidate: BankAccountCandidate): string {
  const name = candidate.name?.trim();
  return name ? `${bank} ${name}` : `${bank} ${ACCOUNT_TYPE_LABELS[candidate.suggested_account_type].toLowerCase()}`;
}

export function duplicateTargets(targets: LinkTarget[]): Set<string> {
  const seen = new Set<string>();
  const duplicates = new Set<string>();
  for (const target of targets) {
    if (!target || target === NEW_ACCOUNT) {
      continue;
    }
    if (seen.has(target)) {
      duplicates.add(target);
    }
    seen.add(target);
  }
  return duplicates;
}

@Component({
  selector: 'app-finance-bank-link-page',
  imports: [ReactiveFormsModule, RouterLink, UiPageHeader, UiCard, UiButton, UiField, UiInput, UiSelect, UiSkeleton, UiEmptyState, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header [heading]="heading()" crumb="Finanzas · Bancos" [backLink]="basePath" />

    @if (renewed()) {
      <div class="notice positive" role="status">
        <ui-icon name="circle-check" />
        <span class="small">Permiso renovado. Tus cuentas siguen vinculadas; revisa que todo esté bien y guarda.</span>
      </div>
    }

    @if (failed(); as message) {
      <ui-card>
        <ui-empty-state icon="triangle-alert" heading="No se han podido cargar las cuentas" [description]="message">
          <a ui-button variant="secondary" [routerLink]="basePath">Volver a bancos</a>
        </ui-empty-state>
      </ui-card>
    } @else if (loading()) {
      <ui-card><ui-skeleton height="160px" /></ui-card>
    } @else if (candidates().length === 0) {
      <ui-card>
        <ui-empty-state icon="landmark" heading="El banco no ha devuelto cuentas" description="Puede que no hayas autorizado ninguna. Renueva la conexión y elige las cuentas en el banco.">
          <a ui-button variant="secondary" [routerLink]="basePath">Volver a bancos</a>
        </ui-empty-state>
      </ui-card>
    } @else {
      <p class="small muted intro">
        Elige a qué cuenta de la app va cada cuenta del banco. Los movimientos se importan desde la fecha que indiques: si ya apuntaste a mano los
        anteriores, deja la de hoy para no duplicarlos.
      </p>
      <form class="stack" [formGroup]="form" (ngSubmit)="save()" novalidate>
        @for (row of rows.controls; track row.controls.externalUid.value; let index = $index) {
          <ui-card [formGroup]="row">
            <div class="row identity">
              <span class="ico"><ui-icon [name]="icon(candidates()[index])" /></span>
              <span class="names">
                <span class="name">{{ title(candidates()[index]) }}</span>
                <span class="small faint">{{ subtitle(candidates()[index]) }}</span>
              </span>
            </div>
            <div class="grid-cards g-2 fields">
              <ui-field label="Vincular con" [for]="'fin-link-target-' + index" [error]="targetError(row.controls.target.value)">
                <ui-select formControlName="target" [inputId]="'fin-link-target-' + index" [options]="targetOptions()" />
              </ui-field>
              @if (row.controls.target.value !== null) {
                <ui-field
                  label="Importar desde"
                  [for]="'fin-link-from-' + index"
                  hint="Los movimientos anteriores a esta fecha no se importan."
                >
                  <input ui-input type="date" [id]="'fin-link-from-' + index" [max]="today" formControlName="from" />
                </ui-field>
              }
              @if (row.controls.target.value === newAccount) {
                <ui-field label="Nombre de la cuenta nueva" [for]="'fin-link-name-' + index">
                  <input ui-input type="text" maxlength="120" [id]="'fin-link-name-' + index" formControlName="name" />
                </ui-field>
                <ui-field label="Tipo" [for]="'fin-link-type-' + index">
                  <ui-select formControlName="type" [inputId]="'fin-link-type-' + index" [options]="typeOptions" />
                </ui-field>
              }
            </div>
          </ui-card>
        }
        @if (error(); as message) {
          <p class="field-error" role="alert">{{ message }}</p>
        }
        <div class="row end">
          <a ui-button variant="ghost" [routerLink]="basePath">Más tarde</a>
          <button ui-button type="submit" variant="primary" icon="check" [loading]="saving()" [disabled]="hasDuplicates()">Guardar y sincronizar</button>
        </div>
      </form>
    }
  `,
  styles: `
    .notice {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 16px;
      margin-bottom: 16px;
      border-radius: var(--r-md);
    }
    .notice.positive {
      background: var(--positive-soft);
      color: var(--positive);
    }
    .notice span {
      color: var(--text);
    }
    .intro {
      margin: 0 0 16px;
    }
    .identity {
      gap: 12px;
      min-width: 0;
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      flex: none;
      background: var(--surface-2);
      color: var(--text);
    }
    .names {
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .name {
      font-weight: 600;
    }
    .fields {
      margin-top: 12px;
    }
    .end {
      justify-content: flex-end;
      gap: 8px;
    }
  `,
})
export class BankLinkPage {
  private readonly bank = inject(BankService);
  private readonly accounts = inject(AccountsService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);

  readonly id = input.required<string>();
  readonly renovado = input<string | null>(null);

  protected readonly basePath = BANK_SETTINGS_PATH;
  protected readonly newAccount = NEW_ACCOUNT;
  protected readonly today = todayIso();
  protected readonly connection = signal<BankConnection | null>(null);
  protected readonly candidates = signal<BankAccountCandidate[]>([]);
  protected readonly loading = signal(true);
  protected readonly failed = signal<string | null>(null);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly heading = computed(() => {
    const connection = this.connection();
    return connection ? `Vincular cuentas de ${connection.aspsp_name}` : 'Vincular cuentas';
  });
  protected readonly renewed = computed(() => this.renovado() === '1');

  protected readonly rows = new FormArray<LinkRow>([]);
  protected readonly form = new FormGroup({ rows: this.rows });
  private readonly targets = signal<LinkTarget[]>([]);
  protected readonly duplicates = computed(() => duplicateTargets(this.targets()));
  protected readonly hasDuplicates = computed(() => this.duplicates().size > 0);

  protected readonly typeOptions: UiSelectOption<AccountType>[] = (Object.keys(ACCOUNT_TYPE_LABELS) as AccountType[]).map((type) => ({
    value: type,
    label: ACCOUNT_TYPE_LABELS[type],
    icon: ACCOUNT_TYPE_ICONS[type],
  }));

  protected readonly targetOptions = computed<UiSelectOption<LinkTarget>[]>(() => [
    { value: NEW_ACCOUNT, label: 'Crear cuenta nueva', icon: 'plus' },
    ...this.selectableAccounts().map((account) => ({
      value: account.id,
      label: account.name,
      icon: account.icon ?? ACCOUNT_TYPE_ICONS[account.type],
      description: account.bank && account.bank.connection_id !== this.id() ? `Ya vinculada a ${account.bank.aspsp_name}` : null,
    })),
    { value: null, label: 'No importar', icon: 'eye-off' },
  ]);

  private readonly selectableAccounts = computed<Account[]>(() =>
    this.accounts.active().filter((account) => account.type !== 'cash' || account.bank !== null),
  );

  constructor() {
    effect(() => {
      const id = this.id();
      untracked(() => void this.load(id));
    });
    this.rows.valueChanges.pipe(takeUntilDestroyed()).subscribe(() => this.targets.set(this.rows.controls.map((row) => row.controls.target.value)));
  }

  protected title(candidate: BankAccountCandidate | undefined): string {
    return candidate ? candidateTitle(candidate) : '';
  }

  protected subtitle(candidate: BankAccountCandidate | undefined): string {
    return candidate ? candidateSubtitle(candidate) : '';
  }

  protected icon(candidate: BankAccountCandidate | undefined): string {
    return candidate ? ACCOUNT_TYPE_ICONS[candidate.suggested_account_type] : 'landmark';
  }

  protected targetError(target: LinkTarget): string | null {
    return target && this.duplicates().has(target) ? 'Esta cuenta ya está elegida para otra cuenta del banco.' : null;
  }

  protected async save(): Promise<void> {
    if (this.hasDuplicates()) {
      return;
    }
    const items: BankAccountLinkInput[] = this.rows.controls.map((row) => {
      const value = row.getRawValue();
      if (value.target === null) {
        return { external_account_uid: value.externalUid, account_id: null };
      }
      const item: BankAccountLinkInput = {
        external_account_uid: value.externalUid,
        account_id: value.target,
        sync_from_date: value.from || this.today,
      };
      if (value.target === NEW_ACCOUNT) {
        item.name = value.name.trim() || null;
        item.type = value.type;
      }
      return item;
    });
    this.saving.set(true);
    this.error.set(null);
    try {
      const connection = await this.bank.link(this.id(), items);
      const linked = items.filter((item) => item.account_id !== null).length;
      this.toast.show(
        linked === 0
          ? `${connection.aspsp_name}: no se importará ninguna cuenta`
          : `${connection.aspsp_name} vinculado · importando movimientos`,
      );
      void this.router.navigateByUrl(BANK_SETTINGS_PATH);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido vincular las cuentas.'));
    } finally {
      this.saving.set(false);
    }
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.failed.set(null);
    try {
      const [connection, candidates] = await Promise.all([this.bank.get(id), this.bank.bankAccounts(id)]);
      this.connection.set(connection);
      this.candidates.set(candidates);
      this.rows.clear({ emitEvent: false });
      for (const candidate of candidates) {
        this.rows.push(this.rowFor(connection, candidate), { emitEvent: false });
      }
      this.targets.set(this.rows.controls.map((row) => row.controls.target.value));
    } catch (error) {
      this.failed.set(firstValidationMessage(error, 'Vuelve a la lista de bancos e inténtalo de nuevo.'));
    } finally {
      this.loading.set(false);
    }
  }

  private rowFor(connection: BankConnection, candidate: BankAccountCandidate): LinkRow {
    const linked = candidate.linked_account;
    return new FormGroup({
      externalUid: new FormControl(candidate.external_account_uid, { nonNullable: true }),
      target: new FormControl<LinkTarget>(linked?.id ?? NEW_ACCOUNT),
      name: new FormControl(defaultNewAccountName(connection.aspsp_name, candidate), { nonNullable: true }),
      type: new FormControl<AccountType>(candidate.suggested_account_type, { nonNullable: true }),
      from: new FormControl(linked?.sync_from_date ?? this.today, { nonNullable: true }),
    });
  }
}
