import { booleanAttribute, ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { UiIcon } from '../icon/icon';
import { UiSpinner } from '../spinner/spinner';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

@Component({
  selector: 'button[ui-button], a[ui-button]',
  imports: [UiIcon, UiSpinner],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    class: 'ui-button',
    '[class]': 'classes()',
    '[attr.aria-busy]': 'loading() || null',
    '[attr.disabled]': 'disabledAttr()',
    '[attr.aria-disabled]': 'disabled() || loading() || null',
  },
  template: `
    @if (loading()) {
      <ui-spinner [size]="spinnerSize()" />
    } @else if (icon()) {
      <ui-icon [name]="icon()!" [size]="iconSize()" />
    }
    @if (!iconOnly() || !icon()) {
      <ng-content />
    }
    @if (trailingIcon() && !loading()) {
      <ui-icon [name]="trailingIcon()!" [size]="iconSize()" />
    }
  `,
  styles: `
    :host {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      height: 40px;
      padding: 0 18px;
      border-radius: var(--r-control);
      border: 1px solid transparent;
      font-weight: 600;
      font-size: 15px;
      line-height: 1;
      cursor: pointer;
      white-space: nowrap;
      text-decoration: none;
      transition: background var(--motion-fast);
      user-select: none;
    }
    :host(.size-sm) {
      height: 32px;
      padding: 0 12px;
      font-size: 14px;
    }
    :host(.size-lg) {
      height: 52px;
      padding: 0 24px;
      border-radius: 16px;
      font-size: 17px;
    }
    :host(.icon-only) {
      width: 40px;
      padding: 0;
    }
    :host(.icon-only.size-sm) {
      width: 32px;
    }
    :host(.icon-only.size-lg) {
      width: 48px;
    }
    :host(.block) {
      display: flex;
      width: 100%;
    }
    :host(.variant-primary) {
      background: var(--primary);
      color: var(--on-primary);
    }
    :host(.variant-primary:hover) {
      background: var(--primary-hover);
    }
    :host(.variant-secondary) {
      background: transparent;
      border-color: var(--border);
      color: var(--text);
    }
    :host(.variant-secondary:hover) {
      background: var(--surface-2);
    }
    :host(.variant-ghost) {
      background: var(--surface-2);
      color: var(--text);
    }
    :host(.variant-ghost:hover) {
      background: var(--surface-2);
    }
    :host(.variant-danger) {
      background: var(--negative);
      color: #fff;
    }
    :host(.variant-danger:hover) {
      filter: brightness(0.95);
    }
    :host(:focus-visible) {
      border-radius: var(--r-control);
    }
    :host(.icon-only),
    :host(.icon-only:focus-visible) {
      border-radius: var(--r-full);
    }
    :host([disabled]),
    :host([aria-disabled='true']) {
      opacity: 0.5;
      cursor: default;
      pointer-events: none;
    }
    :host([aria-busy='true']) {
      opacity: 0.8;
    }
  `,
})
export class UiButton {
  readonly variant = input<ButtonVariant>('secondary');
  readonly size = input<ButtonSize>('md');
  readonly icon = input<string | null>(null);
  readonly trailingIcon = input<string | null>(null);
  readonly iconOnly = input(false, { transform: booleanAttribute });
  readonly block = input(false, { transform: booleanAttribute });
  readonly loading = input(false, { transform: booleanAttribute });
  readonly disabled = input(false, { transform: booleanAttribute });

  protected readonly classes = computed(() =>
    [
      'ui-button',
      `variant-${this.variant()}`,
      `size-${this.size()}`,
      this.iconOnly() ? 'icon-only' : '',
      this.block() ? 'block' : '',
    ].join(' '),
  );
  protected readonly iconSize = computed(() => (this.size() === 'lg' && this.iconOnly() ? 22 : 18));
  protected readonly spinnerSize = computed(() => (this.size() === 'sm' ? 14 : 16));
  protected readonly disabledAttr = computed(() => (this.disabled() || this.loading() ? '' : null));
}
