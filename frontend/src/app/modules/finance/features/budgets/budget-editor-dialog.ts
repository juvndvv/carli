import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormArray, FormControl, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiIcon } from '@ui/icon/icon';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiSwitch } from '@ui/switch/switch';
import { BudgetsService } from '../../data-access/budgets.service';
import { CategoriesService, FALLBACK_CATEGORY_ICON } from '../../data-access/categories.service';
import { BudgetOverview, BudgetRow, BudgetUpsertItem, Period } from '../../data-access/finance.models';

export interface BudgetEditorData {
  period: Period;
  rows: BudgetRow[];
}

interface EditorLine {
  categoryId: string;
  name: string;
  icon: string;
  child: boolean;
  amount: number | null;
  rollover: boolean;
}

type LineGroup = FormGroup<{ amount: FormControl<number | null>; rollover: FormControl<boolean> }>;

@Component({
  selector: 'fin-budget-editor-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiMoneyInput, UiSwitch, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Editar presupuestos" [subtitle]="data.period.label">
      <p class="small muted">
        Deja el importe vacío para quitar el presupuesto. Un presupuesto de categoría principal incluye sus subcategorías.
      </p>
      <form class="lines" [formGroup]="form" (ngSubmit)="save()">
        <div class="line head caption" aria-hidden="true">
          <span>Categoría</span>
          <span>Límite</span>
          <span>Arrastrar</span>
        </div>
        <div formArrayName="lines">
          @for (group of form.controls.lines.controls; track lines[$index].categoryId; let index = $index) {
            <div class="line" [class.child]="lines[index].child" [formGroupName]="index">
              <span class="row name">
                <span class="ico"><ui-icon [name]="lines[index].icon" [size]="16" /></span>
                <span class="text">{{ lines[index].name }}</span>
              </span>
              <ui-money-input appearance="field" formControlName="amount" placeholder="Sin límite" [ariaLabel]="'Límite de ' + lines[index].name" />
              <ui-switch formControlName="rollover" [label]="'Arrastrar sobrante o exceso de ' + lines[index].name" />
            </div>
          }
        </div>
      </form>
      @if (error()) {
        <p class="field-error" role="alert">{{ error() }}</p>
      }
      <div dialog-footer class="row between">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="button" variant="primary" [loading]="saving()" (click)="save()">Guardar</button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .lines {
      display: flex;
      flex-direction: column;
    }
    .line {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 140px 52px;
      gap: 10px;
      align-items: center;
      min-height: 52px;
      border-bottom: 1px solid var(--border);
    }
    .line.head {
      min-height: 28px;
    }
    .line.child .name {
      padding-left: 24px;
    }
    .name {
      gap: 8px;
      min-width: 0;
    }
    .text {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .ico {
      width: 28px;
      height: 28px;
      border-radius: 999px;
      background: var(--surface-2);
      display: grid;
      place-items: center;
      flex: none;
    }
    ui-money-input {
      height: 40px;
    }
  `,
})
export class BudgetEditorDialog {
  protected readonly data = inject<BudgetEditorData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<BudgetOverview>>(DialogRef);
  private readonly budgets = inject(BudgetsService);
  private readonly categories = inject(CategoriesService);

  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly lines: EditorLine[] = this.buildLines();
  protected readonly form = new FormGroup({
    lines: new FormArray<LineGroup>(
      this.lines.map(
        (line) =>
          new FormGroup({
            amount: new FormControl<number | null>(line.amount),
            rollover: new FormControl<boolean>(line.rollover, { nonNullable: true }),
          }),
      ),
    ),
  });

  protected async save(): Promise<void> {
    const changes: BudgetUpsertItem[] = [];
    this.form.controls.lines.controls.forEach((group, index) => {
      const line = this.lines[index];
      const { amount, rollover } = group.getRawValue();
      if (amount === line.amount && rollover === line.rollover) {
        return;
      }
      if (amount === null && line.amount === null) {
        return;
      }
      changes.push({ category_id: line.categoryId, amount_cents: amount, rollover });
    });
    if (changes.length === 0) {
      this.ref.close();
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      this.ref.close(await this.budgets.upsert(this.data.period.id, changes));
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido guardar los presupuestos.'));
    } finally {
      this.saving.set(false);
    }
  }

  private buildLines(): EditorLine[] {
    const existing = new Map(this.data.rows.map((row) => [row.category_id, row]));
    const lines: EditorLine[] = [];
    const add = (id: string, name: string, icon: string, child: boolean) => {
      const row = existing.get(id);
      lines.push({ categoryId: id, name, icon, child, amount: row?.amount_cents ?? null, rollover: row?.rollover ?? false });
      existing.delete(id);
    };
    for (const parent of this.categories.topLevel('expense')) {
      add(parent.id, parent.name, parent.icon ?? FALLBACK_CATEGORY_ICON, false);
      for (const child of parent.children ?? []) {
        add(child.id, child.name, child.icon ?? parent.icon ?? FALLBACK_CATEGORY_ICON, true);
      }
    }
    for (const row of existing.values()) {
      add(row.category_id, row.category.name, row.category.icon ?? FALLBACK_CATEGORY_ICON, row.category.parent_id !== null);
    }
    return lines;
  }
}
