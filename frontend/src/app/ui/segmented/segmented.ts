import { ChangeDetectionStrategy, Component, ElementRef, forwardRef, inject, input, model, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { UiIcon } from '../icon/icon';

export interface UiSegmentedOption<T = string> {
  value: T;
  label: string;
  icon?: string | null;
}

@Component({
  selector: 'ui-segmented',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiSegmented), multi: true }],
  host: { role: 'radiogroup', '[attr.aria-label]': 'ariaLabel()', '(keydown)': 'onKeydown($event)' },
  template: `
    @for (option of options(); track $index) {
      <button
        type="button"
        role="radio"
        [class.on]="option.value === value()"
        [attr.aria-checked]="option.value === value()"
        [attr.tabindex]="option.value === value() || (value() === null && $first) ? 0 : -1"
        [disabled]="disabled()"
        (click)="select(option.value)"
      >
        @if (option.icon) {
          <ui-icon [name]="option.icon" [size]="16" />
        }
        {{ option.label }}
      </button>
    }
  `,
  styles: `
    :host {
      display: inline-flex;
      background: var(--surface-2);
      border-radius: var(--r-control);
      padding: 3px;
      gap: 2px;
      width: 100%;
    }
    button {
      flex: 1;
      min-width: 0;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-size: 14px;
      border: 0;
      background: none;
      height: 34px;
      border-radius: 9px;
      color: var(--text-2);
      font-weight: 600;
      white-space: nowrap;
      transition: background var(--motion-fast);
    }
    button.on {
      background: var(--seg-on, #ffffff);
      color: var(--seg-on-text, #1f1f1f);
      box-shadow: 0 1px 2px rgb(0 0 0 / 0.08);
    }
    button:focus-visible {
      border-radius: 9px;
      box-shadow: 0 0 0 3px var(--focus-ring);
    }
  `,
})
export class UiSegmented<T = string> implements ControlValueAccessor {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);

  readonly options = input<UiSegmentedOption<T>[]>([]);
  readonly value = model<T | null>(null);
  readonly ariaLabel = input<string | null>(null);

  protected readonly disabled = signal(false);
  private onChange: (value: T) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected select(value: T): void {
    this.value.set(value);
    this.onChange(value);
    this.onTouched();
  }

  protected onKeydown(event: KeyboardEvent): void {
    const delta = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
    if (!delta) {
      return;
    }
    event.preventDefault();
    const options = this.options();
    const current = Math.max(
      options.findIndex((option) => option.value === this.value()),
      0,
    );
    const next = (current + delta + options.length) % options.length;
    this.select(options[next].value);
    queueMicrotask(() => this.host.nativeElement.querySelectorAll('button')[next]?.focus());
  }

  writeValue(value: T | null): void {
    this.value.set(value ?? null);
  }

  registerOnChange(fn: (value: T) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
