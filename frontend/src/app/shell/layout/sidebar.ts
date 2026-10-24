import { ChangeDetectionStrategy, Component, inject, output } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { ModuleRegistry } from '@core/modules/app-module';
import { UiBadge } from '@ui/badge/badge';
import { UiIcon } from '@ui/icon/icon';

@Component({
  selector: 'app-sidebar',
  imports: [RouterLink, RouterLinkActive, UiIcon, UiBadge],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <nav class="sidebar" aria-label="Navegación principal">
      <a class="brand" routerLink="/">
        <span class="brand-mark" aria-hidden="true">P</span>
        Personal App
      </a>
      <a
        class="nav-item"
        routerLink="/"
        routerLinkActive="active"
        ariaCurrentWhenActive="page"
        [routerLinkActiveOptions]="{ exact: true }"
      >
        <ui-icon name="house" />
        Inicio
      </a>
      <div class="modules">
        <div class="nav-section caption">Módulos</div>
        @for (module of registry.enabled(); track module.id) {
          <a class="nav-item" [routerLink]="module.basePath">
            <span class="mod-dot"><ui-icon [name]="module.icon" /></span>
            {{ module.name }}
          </a>
          @for (item of module.nav; track item.path) {
            <a
              class="nav-item sub"
              [routerLink]="item.path"
              routerLinkActive="active"
              ariaCurrentWhenActive="page"
              [routerLinkActiveOptions]="{ exact: !!item.exact }"
            >
              {{ item.label }}
            </a>
          }
        }
        @for (module of registry.upcoming(); track module.id) {
          <span class="nav-item disabled" aria-disabled="true">
            <span class="mod-dot"><ui-icon [name]="module.icon" /></span>
            {{ module.name }}
            <ui-badge class="pill">Pronto</ui-badge>
          </span>
        }
      </div>
      <a class="nav-item" routerLink="/dev/ui" routerLinkActive="active" ariaCurrentWhenActive="page">
        <ui-icon name="palette" />
        Design system
      </a>
      <a class="nav-item" routerLink="/ajustes" routerLinkActive="active" ariaCurrentWhenActive="page">
        <ui-icon name="settings" />
        Ajustes
      </a>
      <button type="button" class="nav-item" (click)="logout.emit()">
        <ui-icon name="log-out" />
        Cerrar sesión
      </button>
    </nav>
  `,
  styles: `
    :host {
      display: block;
      width: var(--sidebar-width);
      flex: none;
    }
    .sidebar {
      background: var(--sidebar);
      padding: 12px 8px;
      display: flex;
      flex-direction: column;
      gap: 2px;
      position: sticky;
      top: 0;
      height: 100vh;
      height: 100dvh;
      overflow: hidden;
    }
    .modules {
      flex: 1;
      min-height: 0;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 2px;
      margin: 0 -8px;
      padding: 0 8px 8px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 6px 10px 16px;
      font-weight: 650;
      text-decoration: none;
    }
    .brand-mark {
      width: 30px;
      height: 30px;
      border-radius: 999px;
      background: var(--primary);
      color: var(--on-primary);
      display: grid;
      place-items: center;
      font-weight: 700;
    }
    .nav-section {
      margin: 14px 10px 6px;
    }
    .nav-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 10px;
      border-radius: 10px;
      color: var(--text);
      font-size: 14px;
      border: 0;
      background: none;
      width: 100%;
      text-align: left;
      min-height: 38px;
      text-decoration: none;
    }
    .nav-item:hover {
      background: var(--primary-soft);
    }
    .nav-item.active {
      background: var(--primary-soft);
      font-weight: 500;
    }
    .nav-item.sub {
      padding-left: 38px;
      min-height: 34px;
    }
    .nav-item.disabled {
      opacity: 0.55;
      cursor: default;
    }
    .nav-item.disabled:hover {
      background: none;
    }
    .pill {
      margin-left: auto;
    }
    .mod-dot {
      width: 22px;
      height: 22px;
      display: grid;
      place-items: center;
      flex: none;
    }
  `,
})
export class AppSidebar {
  protected readonly registry = inject(ModuleRegistry);
  readonly logout = output<void>();
}
