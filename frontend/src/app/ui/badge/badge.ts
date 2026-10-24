import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { UiIcon } from '../icon/icon';

export type BadgeTone = 'neutral' | 'primary' | 'positive' | 'warning' | 'negative';

@Component({
  selector: 'ui-badge',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class]': "'tone-' + tone()" },
  template: `
    @if (icon()) {
      <ui-icon [name]="icon()!" [size]="12" />
    }
    <ng-content />
  `,
  styles: `
    :host {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      height: 22px;
      padding: 0 8px;
      border-radius: var(--r-full);
      font-size: 12px;
      line-height: 16px;
      font-weight: 500;
      background: var(--surface-2);
      color: var(--text-2);
      white-space: nowrap;
      flex: none;
    }
    :host(.tone-primary) {
      background: var(--primary-soft);
      color: var(--text);
    }
    :host(.tone-positive) {
      background: var(--positive-soft);
      color: var(--positive);
    }
    :host(.tone-warning) {
      background: var(--warning-soft);
      color: var(--warning);
    }
    :host(.tone-negative) {
      background: var(--negative-soft);
      color: var(--negative);
    }
  `,
})
export class UiBadge {
  readonly tone = input<BadgeTone>('neutral');
  readonly icon = input<string | null>(null);
}
