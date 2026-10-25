import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { SessionStore } from '@core/auth/session.store';
import { ModuleRegistry } from '@core/modules/app-module';
import { NotificationsStore } from '@core/notifications/notifications.store';
import { formatLongDate, todayIso } from '@shared/dates/dates';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { AppNotificationList } from '../notifications/notification-list';
import { AppPendingHomeCard } from '../pending/pending-home-card';
import { AppModuleWidgetCard } from './module-widget-card';

export function greetingFor(hour: number): string {
  if (hour >= 6 && hour < 14) {
    return 'Buenos días';
  }
  if (hour >= 14 && hour < 21) {
    return 'Buenas tardes';
  }
  return 'Buenas noches';
}

const madridHour = (): number =>
  Number(new Intl.DateTimeFormat('es-ES', { hour: 'numeric', hourCycle: 'h23', timeZone: 'Europe/Madrid' }).format(new Date()));

@Component({
  selector: 'app-home-page',
  imports: [UiPageHeader, UiCard, UiBadge, UiButton, UiIcon, RouterLink, AppModuleWidgetCard, AppNotificationList, AppPendingHomeCard],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header [heading]="heading()" [crumb]="today" />
    <app-pending-home-card class="pending" />
    <div class="grid-cards g-3">
      @for (module of registry.enabled(); track module.id) {
        <app-module-widget-card [module]="module" />
      }
      @for (module of registry.upcoming(); track module.id) {
        <ui-card class="upcoming">
          <div class="row between">
            <div class="row">
              <span class="ico"><ui-icon [name]="module.icon" /></span>
              <h2>{{ module.name }}</h2>
            </div>
            <ui-badge>Próximamente</ui-badge>
          </div>
          <p class="small muted description">{{ module.description }}</p>
        </ui-card>
      }
    </div>
    <ui-card heading="Notificaciones recientes" class="notifications">
      <a card-actions ui-button variant="ghost" size="sm" routerLink="/notificaciones">Ver todas</a>
      <app-notification-list [items]="notifications.recent()" />
    </ui-card>
  `,
  styles: `
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: var(--surface-2);
      flex: none;
    }
    .description {
      margin-top: 16px;
    }
    .notifications {
      margin-top: 16px;
    }
    .pending:not(:empty) {
      margin-bottom: 16px;
    }
  `,
})
export class HomePage {
  private readonly session = inject(SessionStore);
  protected readonly registry = inject(ModuleRegistry);
  protected readonly notifications = inject(NotificationsStore);
  protected readonly today = formatLongDate(todayIso());
  protected readonly heading = computed(() => {
    const name = this.session.firstName();
    const greeting = greetingFor(madridHour());
    return name ? `${greeting}, ${name}` : greeting;
  });
}
