import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'ui-skeleton',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    'aria-hidden': 'true',
    '[style.width]': 'width()',
    '[style.height]': 'height()',
    '[style.border-radius]': 'radius()',
  },
  template: '',
  styles: `
    :host {
      display: block;
      background: var(--surface-2);
      animation: ui-pulse 1.4s ease-in-out infinite;
    }
    @keyframes ui-pulse {
      50% {
        opacity: 0.55;
      }
    }
  `,
})
export class UiSkeleton {
  readonly width = input('100%');
  readonly height = input('16px');
  readonly radius = input('var(--r-sm)');
}
