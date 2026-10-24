import { booleanAttribute, ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'textarea[ui-textarea]',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ui-textarea', '[class.invalid]': 'invalid()', '[attr.aria-invalid]': 'invalid() || null' },
  template: '',
  styles: `
    :host {
      min-height: 88px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      background: var(--surface);
      padding: 10px 12px;
      color: var(--text);
      font: inherit;
      width: 100%;
      resize: vertical;
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
  `,
})
export class UiTextarea {
  readonly invalid = input(false, { transform: booleanAttribute });
}
