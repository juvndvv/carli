import { booleanAttribute, ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'input[ui-input], select[ui-input]',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ui-input', '[class.invalid]': 'invalid()', '[attr.aria-invalid]': 'invalid() || null' },
  template: '',
  styles: `
    :host {
      height: 44px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      background: var(--surface);
      padding: 0 12px;
      color: var(--text);
      font: inherit;
      width: 100%;
      min-width: 0;
      transition: border-color var(--motion-fast);
    }
    :host::placeholder {
      color: var(--text-3);
    }
    :host(:focus),
    :host(:focus-visible) {
      outline: none;
      border-color: var(--text-3);
      box-shadow: none;
    }
    :host(.invalid) {
      border-color: var(--negative);
    }
    :host(:disabled) {
      opacity: 0.6;
    }
    :host(select) {
      appearance: none;
      padding-right: 36px;
      background-image: linear-gradient(45deg, transparent 50%, var(--text-3) 50%),
        linear-gradient(135deg, var(--text-3) 50%, transparent 50%);
      background-position:
        calc(100% - 18px) 19px,
        calc(100% - 13px) 19px;
      background-size: 5px 5px;
      background-repeat: no-repeat;
    }
  `,
})
export class UiInput {
  readonly invalid = input(false, { transform: booleanAttribute });
}
