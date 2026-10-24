import { CdkConnectedOverlay, CdkOverlayOrigin, ConnectedPosition } from '@angular/cdk/overlay';
import { CdkPortalOutlet } from '@angular/cdk/portal';
import { ChangeDetectionStrategy, Component, inject, output, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { NotificationsStore } from '@core/notifications/notifications.store';
import { ThemeService } from '@core/theme/theme.service';
import { UiButton } from '@ui/button/button';
import { PageHeaderStore } from '@ui/page-header/page-header.store';
import { UiTooltip } from '@ui/tooltip/tooltip';
import { AppNotificationInbox } from '../notifications/notification-inbox';

const INBOX_POSITIONS: ConnectedPosition[] = [
  { originX: 'end', originY: 'bottom', overlayX: 'end', overlayY: 'top', offsetY: 8 },
];

@Component({
  selector: 'app-topbar',
  imports: [
    CdkPortalOutlet,
    CdkOverlayOrigin,
    CdkConnectedOverlay,
    RouterLink,
    UiButton,
    UiTooltip,
    AppNotificationInbox,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <header class="topbar">
      @if (header.state().backLink) {
        <a
          ui-button
          variant="ghost"
          icon="arrow-left"
          iconOnly
          aria-label="Volver"
          [routerLink]="header.state().backLink"
        ></a>
      }
      <div class="title">
        @if (header.state().crumb) {
          <div class="crumb">{{ header.state().crumb }}</div>
        }
        <h1>{{ header.state().heading }}</h1>
      </div>
      <div class="actions">
        <ng-template [cdkPortalOutlet]="header.state().actions" />
      </div>
      <button
        ui-button
        type="button"
        variant="ghost"
        icon="search"
        iconOnly
        aria-label="Buscar"
        uiTooltip="Buscar (Ctrl/⌘ + K)"
        aria-keyshortcuts="Control+K Meta+K"
        (click)="searchRequested.emit()"
      ></button>
      <button
        ui-button
        type="button"
        variant="ghost"
        iconOnly
        class="d-only"
        [icon]="theme.icon()"
        [attr.aria-label]="'Cambiar tema (actual: ' + theme.label() + ')'"
        [uiTooltip]="'Tema: ' + theme.label()"
        (click)="theme.cycle()"
      ></button>
      <span class="bell" cdkOverlayOrigin #bell="cdkOverlayOrigin">
        <button
          ui-button
          type="button"
          variant="ghost"
          icon="bell"
          iconOnly
          [attr.aria-label]="notifications.unreadCount() > 0 ? 'Notificaciones (' + notifications.unreadCount() + ' sin leer)' : 'Notificaciones'"
          [attr.aria-expanded]="inboxOpen()"
          (click)="toggleInbox()"
        ></button>
        @if (notifications.unreadCount() > 0) {
          <span class="badge-dot" aria-hidden="true"></span>
        }
      </span>
      <ng-template
        cdkConnectedOverlay
        [cdkConnectedOverlayOrigin]="bell"
        [cdkConnectedOverlayOpen]="inboxOpen()"
        [cdkConnectedOverlayPositions]="inboxPositions"
        [cdkConnectedOverlayViewportMargin]="8"
        (overlayOutsideClick)="inboxOpen.set(false)"
        (overlayKeydown)="$event.key === 'Escape' && inboxOpen.set(false)"
        (detach)="inboxOpen.set(false)"
      >
        <app-notification-inbox (closed)="inboxOpen.set(false)" />
      </ng-template>
    </header>
  `,
  styles: `
    .topbar {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 14px 32px;
      position: sticky;
      top: 0;
      background: var(--bg);
      z-index: 5;
    }
    .title {
      flex: 1;
      min-width: 0;
    }
    .title h1 {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .crumb {
      font-size: 13px;
      line-height: 18px;
      color: var(--text-3);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .actions {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .actions:empty {
      display: none;
    }
    .bell {
      position: relative;
      display: inline-flex;
    }
    .badge-dot {
      position: absolute;
      top: 8px;
      right: 9px;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--negative);
      border: 2px solid var(--bg);
      pointer-events: none;
    }
    @media (max-width: 1023px) {
      .topbar {
        padding: 12px 16px;
        gap: 4px;
      }
      .title {
        margin-right: 8px;
      }
    }
  `,
})
export class AppTopbar {
  protected readonly header = inject(PageHeaderStore);
  protected readonly theme = inject(ThemeService);
  protected readonly notifications = inject(NotificationsStore);
  protected readonly inboxOpen = signal(false);
  protected readonly inboxPositions = INBOX_POSITIONS;

  readonly searchRequested = output<void>();

  protected toggleInbox(): void {
    const opening = !this.inboxOpen();
    this.inboxOpen.set(opening);
    if (opening) {
      void this.notifications.refresh();
    }
  }
}
