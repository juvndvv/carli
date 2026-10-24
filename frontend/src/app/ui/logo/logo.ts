import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'ui-logo',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { 'aria-hidden': 'true', '[style.--size.px]': 'size()' },
  template: `
    <svg viewBox="12 12 76 76">
      <rect class="face" x="12" y="12" width="76" height="76" rx="28" />
      <ellipse class="eye" cx="39" cy="47" rx="5.5" ry="9" />
      <ellipse class="eye" cx="61" cy="47" rx="5.5" ry="9" />
    </svg>
  `,
  styles: `
    :host {
      width: var(--size);
      height: var(--size);
      display: inline-block;
      flex: none;
    }
    svg {
      display: block;
      width: 100%;
      height: 100%;
    }
    .face {
      fill: var(--primary);
    }
    .eye {
      fill: var(--on-primary);
    }
  `,
})
export class UiLogo {
  readonly size = input(30);
}
