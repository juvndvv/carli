import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink } from '@angular/router';
import { ModuleRegistry } from '@core/modules/app-module';
import { PendingStore } from '@core/pending/pending.store';
import { UiIcon } from '@ui/icon/icon';
import { filter, map } from 'rxjs';

interface BottomNavEntry {
  label: string;
  path: string;
  icon: string;
  exact: boolean;
}

const MORE_PATH = '/mas';

const pathOf = (url: string): string => url.split(/[?#]/)[0];

@Component({
  selector: 'app-bottom-nav',
  imports: [RouterLink, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <nav class="bottomnav" aria-label="Navegación principal">
      @for (entry of entries(); track entry.path) {
        <a
          [routerLink]="entry.path"
          [class.active]="activePath() === entry.path"
          [attr.aria-current]="activePath() === entry.path ? 'page' : null"
          [attr.aria-label]="entry.path === MORE_PATH && pending.total() > 0 ? entry.label + ' (' + pending.total() + ' pendientes)' : null"
        >
          <span class="glyph">
            <ui-icon [name]="entry.icon" [size]="20" />
            @if (entry.path === MORE_PATH && pending.total() > 0) {
              <span class="badge-dot" aria-hidden="true"></span>
            }
          </span>
          <span>{{ entry.label }}</span>
        </a>
      }
    </nav>
  `,
  styles: `
    .bottomnav {
      display: flex;
      position: fixed;
      left: 0;
      right: 0;
      bottom: 0;
      background: var(--surface);
      border-top: 1px solid var(--border);
      padding: 6px 4px calc(6px + env(safe-area-inset-bottom));
      z-index: 20;
    }
    a {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 2px;
      font-size: 11px;
      line-height: 14px;
      color: var(--text-3);
      padding: 6px 0;
      min-height: 48px;
      text-decoration: none;
    }
    a.active {
      color: var(--text);
      font-weight: 500;
    }
    .glyph {
      position: relative;
      display: inline-flex;
    }
    .badge-dot {
      position: absolute;
      top: -2px;
      right: -4px;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--warning);
      border: 2px solid var(--surface);
    }
  `,
})
export class AppBottomNav {
  private readonly router = inject(Router);
  private readonly registry = inject(ModuleRegistry);
  protected readonly pending = inject(PendingStore);
  protected readonly MORE_PATH = MORE_PATH;
  private readonly url = toSignal(
    this.router.events.pipe(
      filter((event): event is NavigationEnd => event instanceof NavigationEnd),
      map((event) => event.urlAfterRedirects),
    ),
    { initialValue: this.router.url },
  );

  protected readonly entries = computed<BottomNavEntry[]>(() => [
    { label: 'Inicio', path: '/', icon: 'house', exact: true },
    ...this.registry.primaryNav().map((item) => ({ label: item.label, path: item.path, icon: item.icon, exact: !!item.exact })),
    { label: 'Más', path: MORE_PATH, icon: 'menu', exact: false },
  ]);

  protected readonly activePath = computed(() => {
    const current = pathOf(this.url());
    const entries = this.entries();
    const match = entries
      .filter((entry) => entry.path !== MORE_PATH)
      .filter((entry) => (entry.exact ? current === entry.path : current === entry.path || current.startsWith(`${entry.path}/`)))
      .sort((a, b) => b.path.length - a.path.length)[0];
    return match?.path ?? MORE_PATH;
  });
}
