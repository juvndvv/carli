import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiIcon } from '@ui/icon/icon';
import { UiInput } from '@ui/input/input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSwitch } from '@ui/switch/switch';
import { CategoriesService } from '../../data-access/categories.service';
import { CHART_TOKENS } from '../../data-access/finance-format';
import { Category, CategoryInput, CategoryKind, ChartToken } from '../../data-access/finance.models';
import { CATEGORY_ICON_CHOICES } from '../../ui/finance-icons';

export interface CategoryFormData {
  category?: Category | null;
  parentId?: string | null;
  kind: CategoryKind;
}

@Component({
  selector: 'fin-category-form-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiSelect, UiSegmented, UiSwitch, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="category ? 'Editar categoría' : 'Nueva categoría'">
      <form class="stack" [formGroup]="form" (ngSubmit)="save()" novalidate>
        @if (!category) {
          <ui-segmented formControlName="kind" ariaLabel="Tipo de categoría" [options]="kindOptions" />
        }
        <ui-field label="Nombre" for="fin-category-name" [error]="submitted() && form.controls.name.invalid ? 'Ponle un nombre.' : null">
          <input ui-input id="fin-category-name" formControlName="name" autocomplete="off" placeholder="Ej. Mascotas" />
        </ui-field>
        @if (canChangeParent()) {
          <ui-field label="Dentro de" for="fin-category-parent">
            <ui-select inputId="fin-category-parent" formControlName="parent_id" [options]="parentOptions()" />
          </ui-field>
        }
        <div class="field">
          <span class="field-label">Icono</span>
          <div class="icons" role="radiogroup" aria-label="Icono">
            @for (icon of icons; track icon) {
              <button
                type="button"
                role="radio"
                class="icon"
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
        @if (!parentId()) {
          <div class="field">
            <span class="field-label">Color en gráficos</span>
            <div class="swatches" role="radiogroup" aria-label="Color">
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
        }
        @if (kind() === 'income') {
          <div class="row between">
            <span>
              Abre periodo
              <span class="small faint block">Al registrar este ingreso empieza un periodo nuevo (p. ej. la nómina).</span>
            </span>
            <ui-switch formControlName="opens_period" label="Abre periodo" />
          </div>
        }
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
        <button ui-button type="submit" variant="primary" size="lg" block [loading]="saving()">
          {{ category ? 'Guardar cambios' : 'Crear categoría' }}
        </button>
      </form>
    </ui-dialog>
  `,
  styles: `
    .icons {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(40px, 1fr));
      gap: 6px;
      max-height: 196px;
      overflow: auto;
      padding: 2px;
    }
    .icon {
      height: 40px;
      border-radius: 999px;
      border: 0;
      background: var(--surface-2);
      color: var(--text);
      display: grid;
      place-items: center;
    }
    .icon.on {
      background: var(--primary);
      color: var(--on-primary);
    }
    .swatches {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
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
export class CategoryFormDialog {
  private readonly data = inject<CategoryFormData>(DIALOG_DATA);
  private readonly ref = inject<DialogRef<Category>>(DialogRef);
  private readonly categories = inject(CategoriesService);

  protected readonly category = this.data.category ?? null;
  protected readonly icons = CATEGORY_ICON_CHOICES;
  protected readonly colors: readonly ChartToken[] = CHART_TOKENS;
  protected readonly kindOptions: UiSegmentedOption<CategoryKind>[] = [
    { value: 'expense', label: 'Gasto' },
    { value: 'income', label: 'Ingreso' },
  ];
  protected readonly saving = signal(false);
  protected readonly submitted = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly form = new FormGroup({
    kind: new FormControl<CategoryKind>(this.category?.kind ?? this.data.kind, { nonNullable: true }),
    name: new FormControl(this.category?.name ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(80)] }),
    parent_id: new FormControl<string | null>(this.category?.parent_id ?? this.data.parentId ?? null),
    icon: new FormControl<string | null>(this.category?.icon ?? null),
    color: new FormControl<string | null>(this.category?.color ?? null),
    opens_period: new FormControl(this.category?.opens_period ?? false, { nonNullable: true }),
  });

  protected readonly kind = toSignal(this.form.controls.kind.valueChanges, { initialValue: this.form.controls.kind.value });
  protected readonly parentId = toSignal(this.form.controls.parent_id.valueChanges, {
    initialValue: this.form.controls.parent_id.value,
  });
  protected readonly canChangeParent = computed(() => !this.category || (this.category.children ?? []).length === 0);
  protected readonly parentOptions = computed<UiSelectOption<string | null>[]>(() => [
    { value: null, label: 'Ninguna (categoría principal)' },
    ...this.categories
      .topLevel(this.kind())
      .filter((category) => category.id !== this.category?.id)
      .map((category) => ({ value: category.id, label: category.name, icon: category.icon })),
  ]);

  constructor() {
    this.form.controls.kind.valueChanges.subscribe(() => {
      this.form.controls.parent_id.setValue(null);
      this.form.controls.opens_period.setValue(false);
    });
  }

  protected async save(): Promise<void> {
    this.submitted.set(true);
    this.error.set(null);
    if (this.form.invalid) {
      return;
    }
    const value = this.form.getRawValue();
    const input: CategoryInput = {
      name: value.name.trim(),
      icon: value.icon,
      color: value.parent_id ? null : value.color,
      ...(value.kind === 'income' ? { opens_period: value.opens_period } : {}),
      ...(this.canChangeParent() ? { parent_id: value.parent_id } : {}),
      ...(this.category ? {} : value.parent_id ? {} : { kind: value.kind }),
    };
    this.saving.set(true);
    try {
      const saved = this.category ? await this.categories.update(this.category.id, input) : await this.categories.create(input);
      this.ref.close(saved);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar la categoría.'));
    } finally {
      this.saving.set(false);
    }
  }
}
