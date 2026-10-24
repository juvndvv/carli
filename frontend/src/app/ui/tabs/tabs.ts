import { ChangeDetectionStrategy, Component, ElementRef, inject, input, model } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';

export interface UiTab {
  id: string;
  label: string;
  link?: string;
  badge?: string | number | null;
}

@Component({
  selector: 'ui-tabs',
  imports: [RouterLink, RouterLinkActive],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[attr.role]': "routed() ? 'navigation' : 'tablist'", '[attr.aria-label]': 'ariaLabel()' },
  template: `
    @for (tab of tabs(); track tab.id) {
      @if (tab.link) {
        <a
          class="tab"
          [routerLink]="tab.link"
          routerLinkActive="on"
          #rla="routerLinkActive"
          [attr.aria-current]="rla.isActive ? 'page' : null"
        >
          {{ tab.label }}
          @if (tab.badge !== undefined && tab.badge !== null) {
            <span class="count">{{ tab.badge }}</span>
          }
        </a>
      } @else {
        <button
          type="button"
          role="tab"
          class="tab"
          [class.on]="tab.id === active()"
          [attr.aria-selected]="tab.id === active()"
          [attr.tabindex]="tab.id === active() ? 0 : -1"
          (click)="active.set(tab.id)"
          (keydown)="onKeydown($event)"
        >
          {{ tab.label }}
          @if (tab.badge !== undefined && tab.badge !== null) {
            <span class="count">{{ tab.badge }}</span>
          }
        </button>
      }
    }
  `,
  styles: `
    :host {
      display: flex;
      gap: 4px;
      border-bottom: 1px solid var(--border);
      overflow-x: auto;
      margin-bottom: 16px;
      scrollbar-width: none;
    }
    .tab {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 10px 12px;
      border: 0;
      background: none;
      color: var(--text-2);
      border-bottom: 2px solid transparent;
      white-space: nowrap;
      font-weight: 500;
      text-decoration: none;
      font-size: 15px;
    }
    .tab:hover {
      color: var(--text);
    }
    .tab.on {
      color: var(--text);
      border-bottom-color: var(--text);
    }
    .tab:focus-visible {
      border-radius: var(--r-sm);
    }
    .count {
      font-size: 12px;
      color: var(--text-3);
      font-variant-numeric: tabular-nums;
    }
  `,
})
export class UiTabs {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);

  readonly tabs = input.required<UiTab[]>();
  readonly active = model<string | null>(null);
  readonly ariaLabel = input<string | null>(null);

  protected routed(): boolean {
    return this.tabs().some((tab) => !!tab.link);
  }

  protected onKeydown(event: KeyboardEvent): void {
    const delta = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
    if (!delta) {
      return;
    }
    const tabs = this.tabs();
    const index = tabs.findIndex((tab) => tab.id === this.active());
    const next = (index + delta + tabs.length) % tabs.length;
    this.active.set(tabs[next].id);
    queueMicrotask(() => this.host.nativeElement.querySelectorAll<HTMLElement>('.tab')[next]?.focus());
  }
}
