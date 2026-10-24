import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  forwardRef,
  input,
  model,
  output,
  signal,
  viewChild,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { UiIcon } from '../icon/icon';

@Component({
  selector: 'ui-search',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiSearch), multi: true }],
  template: `
    <ui-icon name="search" class="lead" />
    <input
      #field
      type="search"
      [attr.aria-label]="ariaLabel() || placeholder()"
      [placeholder]="placeholder()"
      [value]="value()"
      [disabled]="disabled()"
      (input)="onInput(field.value)"
      (keydown.enter)="submitted.emit(value())"
      (keydown.escape)="clear()"
      (blur)="onTouched()"
      autocomplete="off"
      enterkeyhint="search"
    />
    @if (value()) {
      <button type="button" class="clear" aria-label="Borrar búsqueda" (click)="clear(); field.focus()">
        <ui-icon name="x" [size]="16" />
      </button>
    }
  `,
  styles: `
    :host {
      position: relative;
      display: flex;
      align-items: center;
      width: 100%;
    }
    .lead {
      position: absolute;
      left: 16px;
      color: var(--text-3);
      pointer-events: none;
    }
    input {
      width: 100%;
      height: 48px;
      border-radius: var(--r-full);
      background: var(--surface-2);
      border: 1px solid transparent;
      padding: 0 44px;
      color: var(--text);
      font: inherit;
    }
    input::placeholder {
      color: var(--text-3);
    }
    input::-webkit-search-cancel-button {
      display: none;
    }
    input:focus {
      outline: none;
      border-color: var(--border);
    }
    input:focus-visible {
      box-shadow: 0 0 0 3px var(--focus-ring);
      border-radius: var(--r-full);
    }
    .clear {
      position: absolute;
      right: 8px;
      width: 32px;
      height: 32px;
      border-radius: var(--r-full);
      border: 0;
      background: none;
      color: var(--text-3);
      display: grid;
      place-items: center;
    }
    .clear:hover {
      background: var(--border);
      color: var(--text);
    }
  `,
})
export class UiSearch implements ControlValueAccessor {
  readonly placeholder = input('Buscar');
  readonly ariaLabel = input<string | null>(null);
  readonly value = model('');
  readonly submitted = output<string>();

  private readonly field = viewChild.required<ElementRef<HTMLInputElement>>('field');
  protected readonly disabled = signal(false);
  private onChange: (value: string) => void = () => undefined;
  protected onTouched: () => void = () => undefined;

  focus(): void {
    this.field().nativeElement.focus();
  }

  protected onInput(text: string): void {
    this.value.set(text);
    this.onChange(text);
  }

  protected clear(): void {
    this.onInput('');
  }

  writeValue(value: string | null): void {
    this.value.set(value ?? '');
  }

  registerOnChange(fn: (value: string) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
