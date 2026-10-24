import { ChangeDetectionStrategy, Component, inject, input, output } from '@angular/core';
import { Router } from '@angular/router';
import { AppNotification, NotificationsStore } from '@core/notifications/notifications.store';
import { UiIcon } from '@ui/icon/icon';
import { formatTimeAgo } from './time-ago';

const TYPE_ICONS: Record<string, string> = {
  budget: 'triangle-alert',
  recurring: 'bell',
  pending: 'clock',
  goal: 'target',
  debt: 'hand-coins',
  summary: 'chart-column',
  period: 'calendar',
  upcoming: 'repeat',
  payroll: 'wallet',
  test: 'bell',
};

export function notificationIcon(notification: AppNotification): string {
  if (notification.data.icon) {
    return notification.data.icon;
  }
  const key = Object.keys(TYPE_ICONS).find((type) => notification.type.toLowerCase().includes(type));
  return key ? TYPE_ICONS[key] : 'bell';
}

@Component({
  selector: 'app-notification-list',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @for (notification of items(); track notification.id) {
      <button type="button" class="item" [class.unread]="!notification.read_at" (click)="open(notification)">
        <span class="ico"><ui-icon [name]="icon(notification)" /></span>
        <span class="body">
          <span class="title">{{ notification.data.title }}</span>
          <span class="subtitle">
            @if (notification.data.body) {
              {{ notification.data.body }} ·
            }
            {{ timeAgo(notification.created_at) }}
          </span>
        </span>
        @if (!notification.read_at) {
          <span class="dot" aria-label="Sin leer"></span>
        }
      </button>
    } @empty {
      <p class="empty small">No tienes notificaciones.</p>
    }
  `,
  styles: `
    :host {
      display: flex;
      flex-direction: column;
    }
    .item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 4px;
      border: 0;
      border-bottom: 1px solid var(--border);
      background: none;
      text-align: left;
      color: var(--text);
      min-height: 56px;
      width: 100%;
    }
    .item:last-of-type {
      border-bottom: 0;
    }
    .item:hover {
      background: var(--surface-2);
      border-radius: var(--r-md);
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      flex: none;
      background: var(--surface-2);
      color: var(--text-2);
    }
    .body {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
    }
    .title {
      font-weight: 500;
    }
    .item:not(.unread) .title {
      font-weight: 400;
    }
    .subtitle {
      font-size: 13px;
      line-height: 18px;
      color: var(--text-3);
    }
    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--negative);
      flex: none;
    }
    .empty {
      color: var(--text-3);
      padding: 16px 4px;
      text-align: center;
    }
  `,
})
export class AppNotificationList {
  private readonly store = inject(NotificationsStore);
  private readonly router = inject(Router);

  readonly items = input.required<AppNotification[]>();
  readonly navigated = output<void>();

  protected icon(notification: AppNotification): string {
    return notificationIcon(notification);
  }

  protected timeAgo(value: string): string {
    return formatTimeAgo(value);
  }

  protected open(notification: AppNotification): void {
    if (!notification.read_at) {
      void this.store.markRead([notification.id]);
    }
    const url = notification.data.url ?? notification.data.action?.url;
    if (url) {
      void this.router.navigateByUrl(url);
      this.navigated.emit();
    }
  }
}
