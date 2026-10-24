import { CdkConnectedOverlay, CdkOverlayOrigin, ConnectedPosition } from '@angular/cdk/overlay';
import {
  booleanAttribute,
  ChangeDetectionStrategy,
  Component,
  computed,
  forwardRef,
  input,
  model,
  output,
  signal,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { UiIcon } from '../icon/icon';
import { OVERLAY_BELOW_THEN_ABOVE, UiSelectOption } from '../select/select-option';

let nextComboboxId = 0;

export const normalizeSearchText = (text: string): string =>
  text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

@Component({
  selector: 'ui-combobox',
  imports: [CdkOverlayOrigin, CdkConnectedOverlay, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiCombobox), multi: true }],
  template: `
    <div class="control" cdkOverlayOrigin #origin="cdkOverlayOrigin">
      @if (icon()) {
        <ui-icon [name]="icon()!" class="lead" />
      }
      <input
        #field
        role="combobox"
        type="text"
        autocomplete="off"
        aria-autocomplete="list"
        [class.with-icon]="!!icon()"
        [attr.id]="inputId()"
        [attr.aria-label]="ariaLabel()"
        [attr.aria-expanded]="open()"
        [attr.aria-controls]="listId"
        [attr.aria-activedescendant]="activeId()"
        [placeholder]="placeholder()"
        [value]="text()"
        [disabled]="disabled()"
        (input)="onInput(field.value)"
        (focus)="openPanel()"
        (blur)="onBlur()"
        (keydown)="onKeydown($event)"
      />
    </div>
    <ng-template
      cdkConnectedOverlay
      [cdkConnectedOverlayOrigin]="origin"
      [cdkConnectedOverlayOpen]="open() && filtered().length > 0"
      [cdkConnectedOverlayPositions]="positions"
      [cdkConnectedOverlayMatchWidth]="true"
      (overlayOutsideClick)="open.set(false)"
      (detach)="open.set(false)"
    >
      <ul class="panel" role="listbox" [attr.id]="listId" [attr.aria-label]="ariaLabel() ?? placeholder()">
        @for (option of filtered(); track $index; let index = $index) {
          <li
            class="option"
            role="option"
            [attr.id]="listId + '-' + index"
            [class.active]="index === activeIndex()"
            [attr.aria-selected]="index === activeIndex()"
            [attr.aria-disabled]="option.disabled || null"
            (mousedown)="$event.preventDefault()"
            (click)="choose(option)"
          >
            @if (option.icon) {
              <ui-icon [name]="option.icon" />
            }
            <span class="text">
              {{ option.label }}
              @if (option.description) {
                <span class="description">{{ option.description }}</span>
              }
            </span>
          </li>
        }
      </ul>
    </ng-template>
  `,
  styleUrl: '../select/overlay-panel.css',
  styles: `
    :host {
      display: block;
      min-width: 0;
    }
    .control {
      position: relative;
      display: flex;
      align-items: center;
    }
    .lead {
      position: absolute;
      left: 12px;
      color: var(--text-3);
      pointer-events: none;
    }
    input {
      width: 100%;
      height: 44px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      background: var(--surface);
      padding: 0 12px;
      color: var(--text);
      font: inherit;
    }
    input.with-icon {
      padding-left: 40px;
    }
    input::placeholder {
      color: var(--text-3);
    }
    input:focus,
    input:focus-visible {
      outline: none;
      border-color: var(--text-3);
      box-shadow: none;
    }
  `,
})
export class UiCombobox<T = string> implements ControlValueAccessor {
  readonly options = input<UiSelectOption<T>[]>([]);
  readonly value = model<T | string | null>(null);
  readonly placeholder = input('');
  readonly ariaLabel = input<string | null>(null);
  readonly inputId = input<string | null>(null);
  readonly icon = input<string | null>(null);
  readonly allowCustom = input(false, { transform: booleanAttribute });
  readonly filterLocally = input(true, { transform: booleanAttribute });
  readonly query = output<string>();
  readonly optionSelected = output<UiSelectOption<T>>();

  protected readonly listId = `ui-combobox-${nextComboboxId++}`;
  protected readonly positions = OVERLAY_BELOW_THEN_ABOVE as unknown as ConnectedPosition[];
  protected readonly open = signal(false);
  protected readonly disabled = signal(false);
  protected readonly text = signal('');
  protected readonly activeIndex = signal(-1);
  protected readonly filtered = computed(() => {
    const options = this.options();
    if (!this.filterLocally()) {
      return options;
    }
    const term = normalizeSearchText(this.text());
    return term === '' ? options : options.filter((option) => normalizeSearchText(option.label).includes(term));
  });
  protected readonly activeId = computed(() =>
    this.open() && this.activeIndex() >= 0 ? `${this.listId}-${this.activeIndex()}` : null,
  );
  private onChange: (value: T | string | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected openPanel(): void {
    this.open.set(true);
  }

  protected onInput(text: string): void {
    this.text.set(text);
    this.open.set(true);
    this.activeIndex.set(this.filtered().length > 0 ? 0 : -1);
    this.query.emit(text);
    if (this.allowCustom()) {
      this.emit(text === '' ? null : text);
    } else if (text === '') {
      this.emit(null);
    }
  }

  protected onKeydown(event: KeyboardEvent): void {
    const count = this.filtered().length;
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this.open.set(true);
        this.activeIndex.set(count === 0 ? -1 : (this.activeIndex() + 1) % count);
        break;
      case 'ArrowUp':
        event.preventDefault();
        this.activeIndex.set(count === 0 ? -1 : (this.activeIndex() - 1 + count) % count);
        break;
      case 'Enter': {
        const option = this.filtered()[this.activeIndex()];
        if (this.open() && option) {
          event.preventDefault();
          this.choose(option);
        }
        break;
      }
      case 'Escape':
        if (this.open()) {
          event.stopPropagation();
          this.open.set(false);
        }
        break;
    }
  }

  protected onBlur(): void {
    this.open.set(false);
    this.onTouched();
    if (!this.allowCustom()) {
      this.text.set(this.labelFor(this.value()));
    }
  }

  protected choose(option: UiSelectOption<T>): void {
    if (option.disabled) {
      return;
    }
    this.text.set(option.label);
    this.open.set(false);
    this.emit(option.value);
    this.optionSelected.emit(option);
  }

  private emit(value: T | string | null): void {
    this.value.set(value);
    this.onChange(value);
  }

  private labelFor(value: T | string | null): string {
    if (value === null) {
      return '';
    }
    return this.options().find((option) => option.value === value)?.label ?? (typeof value === 'string' ? value : '');
  }

  writeValue(value: T | string | null): void {
    this.value.set(value ?? null);
    this.text.set(this.labelFor(value ?? null));
  }

  registerOnChange(fn: (value: T | string | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
