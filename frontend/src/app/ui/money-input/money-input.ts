import {
  booleanAttribute,
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  ElementRef,
  forwardRef,
  input,
  model,
  signal,
  untracked,
  viewChild,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { formatCentsForInput, MINUS_SIGN, parseMoneyInput } from '@shared/money/money';

export type MoneyInputSign = 'none' | 'negative' | 'positive';
export type MoneyInputAppearance = 'display' | 'field';

const ALLOWED_KEYS = /^[0-9.,]$/;

const NARROW_CHARACTERS = /[.,]/;

function displayWidthCh(text: string): number {
  return [...text].reduce((width, character) => width + (NARROW_CHARACTERS.test(character) ? 0.45 : 1), 0);
}

@Component({
  selector: 'ui-money-input',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiMoneyInput), multi: true }],
  host: {
    '[class]': "'appearance-' + appearance()",
    '[class.positive]': "sign() === 'positive'",
    '[class.invalid]': 'invalid()',
    '(click)': 'focus()',
  },
  template: `
    @if (signSymbol()) {
      <span class="sign" aria-hidden="true">{{ signSymbol() }}</span>
    }
    <input
      #field
      class="num"
      type="text"
      inputmode="decimal"
      autocomplete="off"
      [attr.id]="inputId()"
      [attr.aria-label]="ariaLabel()"
      [attr.aria-invalid]="invalid() || null"
      [attr.cdkFocusInitial]="focusInitial() ? '' : null"
      [placeholder]="placeholder()"
      [value]="text()"
      [disabled]="disabled()"
      [style.width.ch]="widthCh()"
      (keydown)="onKeydown($event)"
      (input)="onInput(field.value)"
      (focus)="onFocus()"
      (blur)="onBlur()"
    />
    <span class="currency" aria-hidden="true">€</span>
  `,
  styles: `
    :host {
      display: flex;
      align-items: baseline;
      justify-content: center;
      gap: 4px;
      color: var(--text);
      cursor: text;
    }
    :host(.positive) {
      color: var(--positive);
    }
    input {
      border: 0;
      background: none;
      color: inherit;
      font: inherit;
      text-align: center;
      padding: 0;
      min-width: 0;
      max-width: 100%;
    }
    input::placeholder {
      color: var(--text-3);
    }
    input:focus,
    input:focus-visible {
      outline: none;
      box-shadow: none;
    }
    :host(.appearance-display) {
      font-size: 40px;
      line-height: 48px;
      font-weight: 600;
      letter-spacing: -0.02em;
      padding: 8px 0;
    }
    :host(.appearance-display) .currency,
    :host(.appearance-display) .sign {
      font-weight: 600;
    }
    :host(.appearance-field) {
      justify-content: flex-start;
      height: 44px;
      align-items: center;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      background: var(--surface);
      padding: 0 12px;
    }
    :host(.appearance-field) input {
      text-align: left;
      flex: 1;
    }
    :host(.appearance-field:focus-within) {
      border-color: var(--text-3);
    }
    :host(.invalid) {
      color: var(--negative);
    }
    :host(.appearance-field.invalid) {
      border-color: var(--negative);
    }
    .currency {
      color: var(--text-3);
    }
  `,
})
export class UiMoneyInput implements ControlValueAccessor {
  readonly value = model<number | null>(null);
  readonly sign = input<MoneyInputSign>('none');
  readonly appearance = input<MoneyInputAppearance>('display');
  readonly placeholder = input('0,00');
  readonly ariaLabel = input('Importe');
  readonly inputId = input<string | null>(null);
  readonly allowNegative = input(false, { transform: booleanAttribute });
  readonly focusInitial = input(false, { transform: booleanAttribute });

  private readonly field = viewChild.required<ElementRef<HTMLInputElement>>('field');
  protected readonly text = signal('');
  protected readonly invalid = signal(false);
  protected readonly disabled = signal(false);
  private focused = false;
  private onChange: (value: number | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected readonly signSymbol = computed(() => ({ none: '', negative: MINUS_SIGN, positive: '+' })[this.sign()]);
  protected readonly widthCh = computed(() =>
    this.appearance() === 'display' ? Math.max(displayWidthCh(this.text() || this.placeholder()), 1) + 0.15 : null,
  );

  constructor() {
    effect(() => {
      const value = this.value();
      untracked(() => {
        if (!this.focused) {
          this.invalid.set(false);
          this.text.set(formatCentsForInput(value, true));
        }
      });
    });
  }

  focus(): void {
    this.field().nativeElement.focus();
  }

  protected onKeydown(event: KeyboardEvent): void {
    if (event.ctrlKey || event.metaKey || event.altKey || event.key.length > 1) {
      return;
    }
    const allowsMinus = this.allowNegative() && (event.key === '-' || event.key === MINUS_SIGN);
    if (!ALLOWED_KEYS.test(event.key) && !allowsMinus) {
      event.preventDefault();
    }
  }

  protected onInput(raw: string): void {
    this.text.set(raw);
    const cents = parseMoneyInput(raw);
    const accepted = cents !== null && (this.allowNegative() || cents >= 0);
    this.invalid.set(raw.trim() !== '' && !accepted);
    const next = accepted ? cents : null;
    if (next !== this.value()) {
      this.value.set(next);
      this.onChange(next);
    }
  }

  protected onFocus(): void {
    this.focused = true;
    if (this.invalid()) {
      return;
    }
    const editable = formatCentsForInput(this.value());
    const element = this.field().nativeElement;
    this.text.set(editable);
    if (element.value !== editable) {
      element.value = editable;
      element.select();
    }
  }

  protected onBlur(): void {
    this.focused = false;
    if (!this.invalid()) {
      this.text.set(formatCentsForInput(this.value(), true));
    }
    this.onTouched();
  }

  writeValue(value: number | null): void {
    this.value.set(value ?? null);
    this.invalid.set(false);
    this.text.set(formatCentsForInput(value ?? null, !this.focused));
  }

  registerOnChange(fn: (value: number | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
