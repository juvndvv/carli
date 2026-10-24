import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { CategoriesService, CategoryEntry } from '../../data-access/categories.service';

export interface DeleteCategoryData {
  entry: CategoryEntry;
}

@Component({
  selector: 'fin-delete-category-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiSelect],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="'Eliminar ' + entry.category.name">
      @if (hasChildren) {
        <p class="small muted">Tiene subcategorías. Muévelas o elimínalas antes de borrar esta categoría.</p>
        <div class="row end">
          <button ui-button type="button" variant="secondary" (click)="ref.close()">Entendido</button>
        </div>
      } @else {
        <p class="small muted">
          Si tiene movimientos, presupuestos o recurrentes, elige a qué categoría pasan. Esta acción no se puede deshacer.
        </p>
        <ui-field label="Mover sus movimientos a" for="fin-category-reassign">
          <ui-select inputId="fin-category-reassign" [options]="targets()" [formControl]="target" />
        </ui-field>
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
        <div class="row between">
          <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
          <button ui-button type="button" variant="danger" icon="trash" [loading]="deleting()" (click)="confirm()">Eliminar</button>
        </div>
      }
    </ui-dialog>
  `,
  styles: `
    .end {
      justify-content: flex-end;
    }
  `,
})
export class DeleteCategoryDialog {
  protected readonly entry = inject<DeleteCategoryData>(DIALOG_DATA).entry;
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  private readonly categories = inject(CategoriesService);

  protected readonly hasChildren = (this.entry.category.children ?? []).length > 0;
  protected readonly target = new FormControl<string | null>(null);
  protected readonly deleting = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly targets = computed<UiSelectOption<string | null>[]>(() => [
    { value: null, label: 'No mover (solo si no tiene movimientos)' },
    ...this.categories
      .selectable(this.entry.category.kind)
      .filter((candidate) => candidate.category.id !== this.entry.category.id)
      .map((candidate) => ({ value: candidate.category.id, label: candidate.label, icon: candidate.icon })),
  ]);

  protected async confirm(): Promise<void> {
    this.deleting.set(true);
    this.error.set(null);
    try {
      await this.categories.remove(this.entry.category.id, this.target.value);
      this.ref.close(true);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'Tiene movimientos: elige una categoría a la que moverlos.'));
    } finally {
      this.deleting.set(false);
    }
  }
}
