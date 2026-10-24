import { ChangeDetectionStrategy, Component, inject, output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { NotificationsStore } from '@core/notifications/notifications.store';
import { UiButton } from '@ui/button/button';
import { AppNotificationList } from './notification-list';

@Component({
  selector: 'app-notification-inbox',
  imports: [AppNotificationList, UiButton, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { role: 'dialog', 'aria-label': 'Notificaciones' },
  template: `
    <div class="head">
      <h2>Notificaciones</h2>
      @if (store.unreadCount() > 0) {
        <button ui-button type="button" variant="ghost" size="sm" (click)="store.markRead()">Marcar como leídas</button>
      }
    </div>
    <app-notification-list [items]="store.items().slice(0, 8)" (navigated)="closed.emit()" />
    <a ui-button variant="secondary" size="sm" block routerLink="/notificaciones" (click)="closed.emit()">Ver todas</a>
  `,
  styles: `
    :host {
      display: flex;
      flex-direction: column;
      gap: 8px;
      width: min(380px, calc(100vw - 16px));
      max-height: min(560px, calc(100vh - 96px));
      overflow: auto;
      padding: 16px;
      background: var(--surface);
      border-radius: var(--r-lg);
      box-shadow: var(--shadow-2);
    }
    .head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      padding-bottom: 4px;
    }
  `,
})
export class AppNotificationInbox {
  protected readonly store = inject(NotificationsStore);
  readonly closed = output<void>();
}
