import { ChangeDetectionStrategy, Component, forwardRef, input, model, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { UiIcon } from '../icon/icon';

export interface UiCategoryOption {
  id: string;
  name: string;
  icon: string;
}

@Component({
  selector: 'ui-category-picker',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiCategoryPicker), multi: true }],
  host: { role: 'radiogroup', '[attr.aria-label]': 'ariaLabel()', '[style.--columns]': 'columns()' },
  template: `
    @for (category of categories(); track category.id) {
      <button
        type="button"
        role="radio"
        class="item"
        [class.on]="category.id === value()"
        [attr.aria-checked]="category.id === value()"
        [disabled]="disabled()"
        (click)="select(category.id)"
      >
        <span class="ico"><ui-icon [name]="category.icon" /></span>
        <span class="name">{{ category.name }}</span>
      </button>
    }
  `,
  styles: `
    :host {
      display: grid;
      grid-template-columns: repeat(var(--columns), minmax(0, 1fr));
      gap: 4px;
    }
    .item {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
      padding: 10px 2px;
      border-radius: var(--r-md);
      border: 1px solid transparent;
      background: none;
      font-size: 12px;
      line-height: 16px;
      color: var(--text-2);
      min-height: 44px;
    }
    .item:hover {
      background: var(--surface-2);
    }
    .item.on {
      background: var(--primary-soft);
      color: var(--text);
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: var(--surface-2);
      color: var(--text);
    }
    .item.on .ico {
      background: var(--primary);
      color: var(--on-primary);
    }
    .name {
      max-width: 100%;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  `,
})
export class UiCategoryPicker implements ControlValueAccessor {
  readonly categories = input<UiCategoryOption[]>([]);
  readonly value = model<string | null>(null);
  readonly columns = input(4);
  readonly ariaLabel = input('Categoría');

  protected readonly disabled = signal(false);
  private onChange: (value: string | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected select(id: string): void {
    this.value.set(id);
    this.onChange(id);
    this.onTouched();
  }

  writeValue(value: string | null): void {
    this.value.set(value ?? null);
  }

  registerOnChange(fn: (value: string | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
