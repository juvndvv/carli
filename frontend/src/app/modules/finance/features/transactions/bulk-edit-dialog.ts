import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { AccountsService } from '../../data-access/accounts.service';
import { CategoriesService } from '../../data-access/categories.service';
import { ACCOUNT_TYPE_ICONS, BulkUpdateInput, TransactionStatus } from '../../data-access/finance.models';
import { parseTagInput } from './transaction-form';

type BulkField = 'category' | 'account' | 'tags' | 'status';

export interface BulkEditData {
  count: number;
}

@Component({
  selector: 'fin-bulk-edit-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiSegmented, UiSelect, UiField, UiInput],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Editar en bloque" [subtitle]="subtitle">
      <ui-segmented ariaLabel="Qué quieres cambiar" [options]="fields" [(value)]="field" />
      @switch (field()) {
        @case ('category') {
          <ui-field label="Nueva categoría" for="fin-bulk-category" hint="Las transferencias no cambian de categoría.">
            <ui-select inputId="fin-bulk-category" placeholder="Elige una categoría" [options]="categoryOptions()" [formControl]="category" />
          </ui-field>
        }
        @case ('account') {
          <ui-field label="Nueva cuenta" for="fin-bulk-account" hint="Las transferencias no cambian de cuenta.">
            <ui-select inputId="fin-bulk-account" placeholder="Elige una cuenta" [options]="accountOptions()" [formControl]="account" />
          </ui-field>
        }
        @case ('tags') {
          <ui-field label="Añadir etiquetas" for="fin-bulk-add" hint="Separa varias con comas.">
            <input ui-input id="fin-bulk-add" placeholder="vacaciones, casa" [formControl]="addTags" />
          </ui-field>
          <ui-field label="Quitar etiquetas" for="fin-bulk-remove">
            <input ui-input id="fin-bulk-remove" placeholder="Opcional" [formControl]="removeTags" />
          </ui-field>
        }
        @case ('status') {
          <ui-segmented ariaLabel="Estado" [options]="statusOptions" [formControl]="status" />
        }
      }
      <div dialog-footer class="row between">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="button" variant="primary" [disabled]="!result()" (click)="apply()">Aplicar</button>
      </div>
    </ui-dialog>
  `,
})
export class BulkEditDialog {
  private readonly data = inject<BulkEditData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<Omit<BulkUpdateInput, 'ids'>>>(DialogRef);
  private readonly accounts = inject(AccountsService);
  private readonly categories = inject(CategoriesService);

  protected readonly subtitle = this.data.count === 1 ? '1 movimiento seleccionado' : `${this.data.count} movimientos seleccionados`;
  protected readonly fields: UiSegmentedOption<BulkField>[] = [
    { value: 'category', label: 'Categoría' },
    { value: 'account', label: 'Cuenta' },
    { value: 'tags', label: 'Etiquetas' },
    { value: 'status', label: 'Estado' },
  ];
  protected readonly statusOptions: UiSegmentedOption<TransactionStatus>[] = [
    { value: 'cleared', label: 'Confirmado' },
    { value: 'pending', label: 'Pendiente' },
  ];
  protected readonly field = signal<BulkField>('category');
  protected readonly category = new FormControl<string | null>(null);
  protected readonly account = new FormControl<string | null>(null);
  protected readonly addTags = new FormControl('', { nonNullable: true });
  protected readonly removeTags = new FormControl('', { nonNullable: true });
  protected readonly status = new FormControl<TransactionStatus>('cleared', { nonNullable: true });

  private readonly tick = signal(0);

  protected readonly categoryOptions = computed<UiSelectOption<string>[]>(() =>
    this.categories
      .entries()
      .filter((entry) => !entry.category.archived)
      .map((entry) => ({
        value: entry.category.id,
        label: entry.label,
        icon: entry.icon,
        description: entry.category.kind === 'income' ? 'Ingreso' : null,
      })),
  );
  protected readonly accountOptions = computed<UiSelectOption<string>[]>(() =>
    this.accounts.active().map((account) => ({
      value: account.id,
      label: account.name,
      icon: account.icon ?? ACCOUNT_TYPE_ICONS[account.type],
    })),
  );

  protected readonly result = computed<Omit<BulkUpdateInput, 'ids'> | null>(() => {
    this.tick();
    switch (this.field()) {
      case 'category':
        return this.category.value ? { category_id: this.category.value } : null;
      case 'account':
        return this.account.value ? { account_id: this.account.value } : null;
      case 'tags': {
        const add = parseTagInput(this.addTags.value);
        const remove = parseTagInput(this.removeTags.value);
        return add.length || remove.length
          ? { ...(add.length ? { add_tags: add } : {}), ...(remove.length ? { remove_tags: remove } : {}) }
          : null;
      }
      case 'status':
        return { status: this.status.value };
    }
  });

  constructor() {
    for (const control of [this.category, this.account, this.addTags, this.removeTags, this.status]) {
      control.valueChanges.subscribe(() => this.tick.update((value) => value + 1));
    }
  }

  protected apply(): void {
    const result = this.result();
    if (result) {
      this.ref.close(result);
    }
  }
}
