import { DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { todayIso } from '@shared/dates/dates';
import { UiButton } from '@ui/button/button';
import { UiCategoryOption, UiCategoryPicker } from '@ui/category-picker/category-picker';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { ToastService } from '@ui/toast/toast.service';

@Component({
  selector: 'app-catalog-dialog-example',
  imports: [FormsModule, UiDialog, UiButton, UiSegmented, UiMoneyInput, UiCategoryPicker, UiDatePicker, UiField],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Nuevo movimiento">
      <ui-segmented ariaLabel="Tipo" [options]="kinds" [(value)]="kind" />
      <ui-money-input [(value)]="amount" [sign]="kind() === 'income' ? 'positive' : 'negative'" />
      <ui-field label="Categoría">
        <ui-category-picker [categories]="categories" [(value)]="category" />
      </ui-field>
      <ui-field label="Fecha">
        <ui-date-picker [(value)]="date" />
      </ui-field>
      <button dialog-footer ui-button type="button" variant="primary" size="lg" block (click)="save()">Guardar</button>
    </ui-dialog>
  `,
})
export class CatalogDialogExample {
  private readonly ref = inject(DialogRef);
  private readonly toast = inject(ToastService);

  protected readonly kinds: UiSegmentedOption[] = [
    { value: 'expense', label: 'Gasto' },
    { value: 'income', label: 'Ingreso' },
    { value: 'transfer', label: 'Transferencia' },
  ];
  protected readonly categories: UiCategoryOption[] = [
    { id: 'home', name: 'Vivienda', icon: 'house' },
    { id: 'food', name: 'Alimentación', icon: 'shopping-cart' },
    { id: 'transport', name: 'Transporte', icon: 'car' },
    { id: 'leisure', name: 'Ocio', icon: 'party-popper' },
  ];
  protected readonly kind = signal<string | null>('expense');
  protected readonly amount = signal<number | null>(null);
  protected readonly category = signal<string | null>('food');
  protected readonly date = signal<string | null>(todayIso());

  protected save(): void {
    this.ref.close();
    this.toast.withUndo('Movimiento guardado', () => this.toast.show('Deshecho'));
  }
}
