import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { UiIcon } from '../icon/icon';

@Component({
  selector: 'ui-empty-state',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-icon [name]="icon()" [size]="32" class="icon" />
    <h2>{{ heading() }}</h2>
    @if (description()) {
      <p class="small">{{ description() }}</p>
    }
    <div class="actions"><ng-content /></div>
  `,
  styles: `
    :host {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      padding: 32px 16px;
      color: var(--text-2);
      gap: 4px;
    }
    .icon {
      color: var(--text-3);
      margin-bottom: 4px;
    }
    h2 {
      color: var(--text);
    }
    p {
      max-width: 360px;
    }
    .actions {
      margin-top: 12px;
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: center;
    }
    .actions:empty {
      display: none;
    }
  `,
})
export class UiEmptyState {
  readonly icon = input('inbox');
  readonly heading = input.required<string>();
  readonly description = input<string | null>(null);
}
