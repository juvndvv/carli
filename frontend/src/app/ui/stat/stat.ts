import { booleanAttribute, ChangeDetectionStrategy, Component, input } from '@angular/core';
import { UiIcon } from '../icon/icon';

export type StatTone = 'default' | 'positive' | 'warning' | 'negative' | 'muted';

@Component({
  selector: 'ui-stat',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class.card]': 'card()' },
  template: `
    <div class="label">
      @if (icon()) {
        <ui-icon [name]="icon()!" />
      }
      {{ label() }}
    </div>
    <div class="value num" [class]="'tone-' + tone()">
      @if (value() !== null) {
        {{ value() }}
      } @else {
        <ng-content />
      }
    </div>
    @if (delta()) {
      <div class="delta" [class]="'tone-' + deltaTone()">
        @if (deltaIcon()) {
          <ui-icon [name]="deltaIcon()!" [size]="14" />
        }
        {{ delta() }}
      </div>
    }
  `,
  styles: `
    :host {
      display: block;
      min-width: 0;
      container-type: inline-size;
    }
    :host(.card) {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-lg);
      padding: 20px;
    }
    .label {
      font-size: 13px;
      color: var(--text-2);
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .value {
      font-size: 24px;
      line-height: 32px;
      font-weight: 600;
      margin-top: 4px;
      letter-spacing: -0.01em;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    @container (max-width: 150px) {
      .value {
        font-size: 19px;
        line-height: 28px;
      }
    }
    .delta {
      font-size: 13px;
      margin-top: 2px;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .tone-positive {
      color: var(--positive);
    }
    .tone-warning {
      color: var(--warning);
    }
    .tone-negative {
      color: var(--negative);
    }
    .tone-muted {
      color: var(--text-2);
    }
  `,
})
export class UiStat {
  readonly label = input.required<string>();
  readonly value = input<string | null>(null);
  readonly icon = input<string | null>(null);
  readonly tone = input<StatTone>('default');
  readonly delta = input<string | null>(null);
  readonly deltaIcon = input<string | null>(null);
  readonly deltaTone = input<StatTone>('muted');
  readonly card = input(true, { transform: booleanAttribute });
}
