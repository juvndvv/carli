import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'ui-spinner',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { role: 'status', '[attr.aria-label]': 'label()', '[style.--size.px]': 'size()' },
  template: '',
  styles: `
    :host {
      display: inline-block;
      width: var(--size);
      height: var(--size);
      border-radius: 999px;
      border: 2px solid currentColor;
      border-right-color: transparent;
      animation: ui-spin 0.7s linear infinite;
      flex: none;
    }
    @keyframes ui-spin {
      to {
        transform: rotate(360deg);
      }
    }
  `,
})
export class UiSpinner {
  readonly size = input(16);
  readonly label = input('Cargando');
}
