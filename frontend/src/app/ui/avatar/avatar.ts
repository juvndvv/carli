import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

@Component({
  selector: 'ui-avatar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { role: 'img', '[attr.aria-label]': 'name()', '[style.--size.px]': 'size()' },
  template: `{{ initials() }}`,
  styles: `
    :host {
      width: var(--size);
      height: var(--size);
      border-radius: 999px;
      display: inline-grid;
      place-items: center;
      flex: none;
      background: var(--surface-2);
      color: var(--text);
      font-weight: 650;
      font-size: calc(var(--size) * 0.4);
      line-height: 1;
      user-select: none;
    }
  `,
})
export class UiAvatar {
  readonly name = input.required<string>();
  readonly size = input(36);

  protected readonly initials = computed(() => {
    const words = this.name().trim().split(/\s+/).filter(Boolean);
    const letters = words.length > 1 ? words[0][0] + words[1][0] : (words[0]?.[0] ?? '?');
    return letters.toUpperCase();
  });
}
