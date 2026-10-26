import { booleanAttribute, ChangeDetectionStrategy, Component, input } from '@angular/core';
import { UiIcon } from '../icon/icon';

@Component({
  selector: 'button[ui-chip], a[ui-chip]',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    class: 'ui-chip',
    '[class.on]': 'selected()',
    '[attr.aria-pressed]': 'pressable() ? selected() : null',
  },
  template: `
    @if (icon()) {
      <ui-icon [name]="icon()!" [size]="14" />
    }
    <ng-content />
    @if (trailingIcon()) {
      <ui-icon [name]="trailingIcon()!" [size]="14" />
    }
  `,
  styles: `
    :host {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      height: 32px;
      padding: 0 12px;
      border-radius: 8px;
      border: 1px solid var(--border);
      background: var(--surface);
      font-size: 13px;
      color: var(--text-2);
      white-space: nowrap;
      text-decoration: none;
      flex: none;
      transition: background var(--motion-fast);
    }
    :host(:hover) {
      background: var(--surface-2);
    }
    :host(.on) {
      background: var(--primary);
      border-color: transparent;
      color: var(--on-primary);
      font-weight: 500;
    }
    :host(:focus-visible) {
      border-radius: 8px;
    }
  `,
})
export class UiChip {
  readonly selected = input(false, { transform: booleanAttribute });
  readonly pressable = input(true, { transform: booleanAttribute });
  readonly icon = input<string | null>(null);
  readonly trailingIcon = input<string | null>(null);
}
