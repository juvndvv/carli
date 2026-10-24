import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { normalizeSearchText } from '@ui/combobox/combobox';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiIcon } from '@ui/icon/icon';
import { UiSearch } from '@ui/search/search';

export interface FilterOption {
  value: string;
  label: string;
  icon?: string | null;
  indent?: boolean;
  description?: string | null;
}

export interface FilterOptionsData {
  title: string;
  options: FilterOption[];
  selected: string[];
  searchable?: boolean;
  emptyText?: string;
}

@Component({
  selector: 'fin-filter-options-dialog',
  imports: [UiDialog, UiButton, UiIcon, UiSearch],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="data.title">
      @if (data.searchable) {
        <ui-search placeholder="Buscar" ariaLabel="Buscar opciones" [(value)]="query" />
      }
      <div class="options" role="group" [attr.aria-label]="data.title">
        @for (option of visible(); track option.value) {
          <button
            type="button"
            class="option"
            role="checkbox"
            [class.indent]="option.indent"
            [attr.aria-checked]="isSelected(option.value)"
            (click)="toggle(option.value)"
          >
            <ui-icon [name]="isSelected(option.value) ? 'circle-check' : 'circle'" class="check" />
            @if (option.icon) {
              <span class="ico"><ui-icon [name]="option.icon" [size]="16" /></span>
            }
            <span class="text">
              {{ option.label }}
              @if (option.description) {
                <span class="small faint">{{ option.description }}</span>
              }
            </span>
          </button>
        } @empty {
          <p class="small muted empty">{{ data.emptyText ?? 'No hay opciones.' }}</p>
        }
      </div>
      <div dialog-footer class="row between footer">
        <button ui-button type="button" variant="ghost" (click)="selected.set([])">Limpiar</button>
        <button ui-button type="button" variant="primary" (click)="apply()">Aplicar</button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .options {
      display: flex;
      flex-direction: column;
      max-height: 50vh;
      overflow: auto;
      margin: 0 -8px;
    }
    .option {
      display: flex;
      align-items: center;
      gap: 10px;
      min-height: 44px;
      padding: 6px 8px;
      border: 0;
      border-radius: var(--r-md);
      background: none;
      color: var(--text);
      text-align: left;
      font: inherit;
    }
    .option:hover {
      background: var(--surface-2);
    }
    .option.indent {
      padding-left: 36px;
    }
    .check {
      color: var(--text-2);
    }
    .option[aria-checked='true'] .check {
      color: var(--text);
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
    .text {
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .empty {
      padding: 8px;
    }
    .footer {
      gap: 8px;
    }
  `,
})
export class FilterOptionsDialog {
  protected readonly data = inject<FilterOptionsData>(DIALOG_DATA);
  private readonly ref = inject<DialogRef<string[]>>(DialogRef);

  protected readonly selected = signal<string[]>([...this.data.selected]);
  protected readonly query = signal('');
  protected readonly visible = computed(() => {
    const term = normalizeSearchText(this.query());
    return term === ''
      ? this.data.options
      : this.data.options.filter((option) => normalizeSearchText(option.label).includes(term));
  });

  protected isSelected(value: string): boolean {
    return this.selected().includes(value);
  }

  protected toggle(value: string): void {
    this.selected.update((current) =>
      current.includes(value) ? current.filter((item) => item !== value) : [...current, value],
    );
  }

  protected apply(): void {
    this.ref.close(this.selected());
  }
}
