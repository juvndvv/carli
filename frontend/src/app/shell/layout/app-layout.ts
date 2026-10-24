import { DialogRef } from '@angular/cdk/dialog';
import { DOCUMENT } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, OnInit, untracked } from '@angular/core';
import { Router, RouterOutlet } from '@angular/router';
import { AuthService } from '@core/auth/auth.service';
import { ModuleRegistry } from '@core/modules/app-module';
import { NotificationsStore } from '@core/notifications/notifications.store';
import { PushService } from '@core/push/push.service';
import { QuickAddRegistry } from '@core/quick-add';
import { SearchService } from '@core/search/search.service';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiIcon } from '@ui/icon/icon';
import { AppGlobalSearch } from '../search/global-search';
import { AppBottomNav } from './bottom-nav';
import { AppSidebar } from './sidebar';
import { AppTopbar } from './topbar';

const NOTIFICATIONS_REFRESH_MS = 120_000;

@Component({
  selector: 'app-layout',
  imports: [RouterOutlet, AppSidebar, AppTopbar, AppBottomNav, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '(document:keydown)': 'onGlobalKeydown($event)' },
  template: `
    <a class="skip-link" href="#main-content">Saltar al contenido</a>
    <div class="app">
      <app-sidebar class="d-only" (logout)="logout()" />
      <div class="main">
        <app-topbar (searchRequested)="search.open()" />
        <main id="main-content" class="content" tabindex="-1">
          <router-outlet />
        </main>
      </div>
    </div>
    <app-bottom-nav class="m-only" />
    @if (quickAdd.primary(); as opener) {
      <button type="button" class="fab m-only" [attr.aria-label]="opener.label" (click)="quickAdd.open()">
        <ui-icon [name]="opener.icon" [size]="24" />
      </button>
    }
  `,
  styles: `
    .app {
      display: flex;
      min-height: 100vh;
      min-height: 100dvh;
    }
    .main {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
    }
    .content {
      padding: 8px 32px 48px;
      max-width: var(--content-max);
      width: 100%;
      outline: none;
    }
    .fab {
      display: grid;
      place-items: center;
      position: fixed;
      right: 16px;
      bottom: calc(80px + env(safe-area-inset-bottom));
      width: 56px;
      height: 56px;
      border-radius: 999px;
      background: var(--primary);
      color: var(--on-primary);
      border: 0;
      box-shadow: var(--shadow-2);
      z-index: 21;
    }
    .fab:focus-visible {
      border-radius: 999px;
    }
    .skip-link {
      position: absolute;
      left: 8px;
      top: -48px;
      z-index: 100;
      background: var(--primary);
      color: var(--on-primary);
      padding: 8px 12px;
      border-radius: var(--r-md);
    }
    .skip-link:focus {
      top: 8px;
    }
    @media (max-width: 1023px) {
      .content {
        padding: 4px 16px calc(120px + env(safe-area-inset-bottom));
      }
    }
  `,
})
export class AppLayout implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly registry = inject(ModuleRegistry);
  private readonly notifications = inject(NotificationsStore);
  private readonly dialogs = inject(DialogService);
  private readonly document = inject(DOCUMENT);
  private readonly destroyRef = inject(DestroyRef);
  private searchRef: DialogRef<unknown, AppGlobalSearch> | null = null;

  protected readonly search = inject(SearchService);
  protected readonly quickAdd = inject(QuickAddRegistry);

  constructor() {
    inject(PushService);
    effect(() => {
      if (this.search.isOpen()) {
        untracked(() => this.openSearch());
      }
    });
  }

  ngOnInit(): void {
    if (!this.registry.loaded()) {
      void this.registry.load();
    }
    void this.notifications.refresh();
    const timer = setInterval(() => {
      if (this.document.visibilityState === 'visible') {
        void this.notifications.refresh();
      }
    }, NOTIFICATIONS_REFRESH_MS);
    this.destroyRef.onDestroy(() => clearInterval(timer));
  }

  protected onGlobalKeydown(event: KeyboardEvent): void {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      this.search.open();
    }
  }

  protected async logout(): Promise<void> {
    await this.auth.logout();
    await this.router.navigateByUrl('/login');
  }

  private openSearch(): void {
    if (this.searchRef) {
      return;
    }
    this.searchRef = this.dialogs.open(AppGlobalSearch, { size: 'lg', ariaLabel: 'Búsqueda global' });
    this.searchRef.closed.subscribe(() => {
      this.searchRef = null;
      this.search.close();
    });
  }
}
