import { booleanAttribute, ChangeDetectionStrategy, Component, input } from '@angular/core';
import { UiIcon } from '../icon/icon';

export type ListValueTone = 'default' | 'positive' | 'negative' | 'muted';

@Component({
  selector: 'ui-list-item, a[ui-list-item], button[ui-list-item]',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ui-list-item', '[class.interactive]': 'interactive()' },
  template: `
    <ng-content select="[leading]">
      @if (icon()) {
        <span class="ico" [class.soft]="iconSoft()"><ui-icon [name]="icon()!" /></span>
      }
    </ng-content>
    <span class="body">
      <span class="title">{{ heading() }}</span>
      @if (subtitle()) {
        <span class="subtitle">{{ subtitle() }}</span>
      }
      <ng-content />
      <span class="badges"><ng-content select="[badges]" /></span>
    </span>
    <ng-content select="[trailing]">
      @if (value() !== null) {
        <span class="value num" [class]="'tone-' + valueTone()">{{ value() }}</span>
      }
    </ng-content>
  `,
  styles: `
    :host {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 4px;
      border-bottom: 1px solid var(--border);
      min-height: 56px;
      color: var(--text);
      text-decoration: none;
      background: none;
      border-left: 0;
      border-right: 0;
      border-top: 0;
      width: 100%;
      text-align: left;
      font: inherit;
    }
    :host(:last-child) {
      border-bottom: 0;
    }
    :host(.interactive),
    :host(a),
    :host(button) {
      cursor: pointer;
      border-radius: var(--r-md);
      transition: background var(--motion-fast);
    }
    :host(.interactive:hover),
    :host(a:hover),
    :host(button:hover) {
      background: var(--surface-2);
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      flex: none;
      background: var(--surface-2);
      color: var(--text);
    }
    .ico.soft {
      color: var(--text-2);
    }
    .body {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
    }
    .title {
      font-weight: 500;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .subtitle {
      font-size: 13px;
      line-height: 18px;
      color: var(--text-3);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .badges {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
      margin-top: 4px;
    }
    .badges:empty {
      display: none;
    }
    .value {
      font-weight: 550;
      text-align: right;
      white-space: nowrap;
    }
    .tone-positive {
      color: var(--positive);
    }
    .tone-negative {
      color: var(--negative);
    }
    .tone-muted {
      color: var(--text-2);
    }
  `,
})
export class UiListItem {
  readonly heading = input.required<string>();
  readonly subtitle = input<string | null>(null);
  readonly icon = input<string | null>(null);
  readonly iconSoft = input(false, { transform: booleanAttribute });
  readonly value = input<string | null>(null);
  readonly valueTone = input<ListValueTone>('default');
  readonly interactive = input(false, { transform: booleanAttribute });
}
