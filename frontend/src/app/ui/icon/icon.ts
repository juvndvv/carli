import { ChangeDetectionStrategy, Component, computed, inject, input } from '@angular/core';
import { LucideDynamicIcon } from '@lucide/angular';
import { IconRegistry } from './icon-registry';

@Component({
  selector: 'ui-icon',
  imports: [LucideDynamicIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    class: 'ui-icon',
    'aria-hidden': 'true',
    '[style.width.px]': 'size()',
    '[style.height.px]': 'size()',
  },
  template: `
    @if (data(); as icon) {
      <svg [lucideIcon]="icon" [size]="size()" [strokeWidth]="strokeWidth()"></svg>
    }
  `,
  styles: `
    :host {
      display: inline-flex;
      flex: none;
      align-items: center;
      justify-content: center;
      line-height: 0;
    }
  `,
})
export class UiIcon {
  private readonly registry = inject(IconRegistry);

  readonly name = input.required<string>();
  readonly size = input(18);
  readonly strokeWidth = input(1.75);

  protected readonly data = computed(() => this.registry.get(this.name()) ?? this.registry.get('circle'));
}
