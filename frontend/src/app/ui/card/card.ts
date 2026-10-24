import { booleanAttribute, ChangeDetectionStrategy, Component, input } from '@angular/core';

export type CardPadding = 'none' | 'sm' | 'md' | 'list';

@Component({
  selector: 'ui-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ui-card', '[class]': "'padding-' + padding()", '[class.interactive]': 'interactive()' },
  template: `
    @if (heading()) {
      <div class="head">
        <h2>{{ heading() }}</h2>
        <ng-content select="[card-actions]" />
      </div>
    }
    <ng-content />
  `,
  styles: `
    :host {
      display: block;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-lg);
      min-width: 0;
    }
    :host(.padding-md) {
      padding: 20px;
    }
    :host(.padding-sm) {
      padding: 12px 16px;
    }
    :host(.padding-list) {
      padding: 8px 16px;
    }
    :host(.interactive) {
      cursor: pointer;
      transition: background var(--motion-fast);
    }
    :host(.interactive:hover) {
      background: var(--surface-2);
    }
    .head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 14px;
    }
    :host(.padding-list) .head {
      margin: 8px 0 6px;
    }
  `,
})
export class UiCard {
  readonly heading = input<string | null>(null);
  readonly padding = input<CardPadding>('md');
  readonly interactive = input(false, { transform: booleanAttribute });
}
