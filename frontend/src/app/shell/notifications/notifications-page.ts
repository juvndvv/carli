import { ChangeDetectionStrategy, Component, inject, OnInit } from '@angular/core';
import { NotificationsStore } from '@core/notifications/notifications.store';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiPageHeader } from '@ui/page-header/page-header';
import { AppNotificationList } from './notification-list';

@Component({
  selector: 'app-notifications-page',
  imports: [UiPageHeader, UiCard, UiButton, AppNotificationList],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Notificaciones" crumb="Bandeja">
      @if (store.unreadCount() > 0) {
        <button ui-button type="button" variant="secondary" size="sm" icon="check-check" (click)="store.markRead()">
          <span class="d-only">Marcar como leídas</span>
        </button>
      }
    </ui-page-header>
    <ui-card padding="list">
      <app-notification-list [items]="store.items()" />
    </ui-card>
    @if (store.hasMore()) {
      <div class="more">
        <button ui-button type="button" variant="ghost" [loading]="store.loading()" (click)="store.loadMore()">
          Cargar más
        </button>
      </div>
    }
  `,
  styles: `
    .more {
      display: flex;
      justify-content: center;
      margin-top: 16px;
    }
  `,
})
export class NotificationsPage implements OnInit {
  protected readonly store = inject(NotificationsStore);

  ngOnInit(): void {
    void this.store.refresh();
  }
}
