import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { ModuleRegistry } from '@core/modules/app-module';
import { NotificationPreference, NotificationsStore } from '@core/notifications/notifications.store';
import { PushService } from '@core/push/push.service';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiSwitch } from '@ui/switch/switch';
import { ToastService } from '@ui/toast/toast.service';
import { describeUserAgent } from './security-settings';

export const NOTIFICATION_TYPE_LABELS: Record<string, string> = {
  budget_threshold: 'Presupuesto al 80 % y 100 %',
  upcoming_charge: 'Cargo recurrente próximo',
  recurring_pending: 'Recurrente pendiente de confirmar',
  debt_reminder: 'Recordatorio de deudas',
  goal_reached: 'Objetivo alcanzado',
  weekly_summary: 'Resumen semanal (lunes 09:00)',
  payroll_overdue: 'Nómina pendiente de registrar',
  pending_digest: 'Pendientes por revisar (diario 20:00)',
};

export function notificationTypeLabel(preference: NotificationPreference): string {
  if (preference.label) {
    return preference.label;
  }
  const key = preference.type.split('.').pop() ?? preference.type;
  return NOTIFICATION_TYPE_LABELS[key] ?? key.replace(/_/g, ' ');
}

@Component({
  selector: 'app-notification-settings',
  imports: [UiCard, UiBadge, UiButton, UiSwitch, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid-cards g-2">
      <ui-card heading="Notificaciones push">
        <div class="stack">
          <div class="row between">
            <div>
              <div class="strong">Este dispositivo</div>
              <div class="small faint">{{ device }} · {{ pushStatusText() }}</div>
            </div>
            @if (push.subscribed()) {
              <ui-badge tone="positive" icon="check">Activo</ui-badge>
            } @else if (push.permission() === 'denied') {
              <ui-badge tone="negative" icon="bell-off">Bloqueado</ui-badge>
            } @else {
              <ui-badge>Inactivo</ui-badge>
            }
          </div>
          @if (!push.supported) {
            <p class="small muted">
              Las notificaciones push necesitan la app instalada o un navegador compatible, y solo funcionan en la versión publicada.
            </p>
          } @else if (push.permission() === 'denied') {
            <p class="small muted">Has bloqueado las notificaciones. Permítelas en los ajustes del navegador para activarlas.</p>
          } @else {
            <div class="row wrap">
              @if (push.subscribed()) {
                <button ui-button type="button" variant="secondary" icon="send" [loading]="testing()" (click)="sendTest()">
                  Enviar prueba
                </button>
                <button ui-button type="button" variant="ghost" [loading]="push.busy()" (click)="disable()">Desactivar</button>
              } @else {
                <button ui-button type="button" variant="primary" icon="bell" [loading]="push.busy()" (click)="enable()">
                  Activar en este dispositivo
                </button>
              }
            </div>
          }
        </div>
      </ui-card>

      @for (group of groups(); track group.moduleId) {
        <ui-card [heading]="group.name">
          <div class="prefs" role="table" [attr.aria-label]="'Preferencias de ' + group.name">
            <div class="pref head caption" role="row">
              <span role="columnheader">Aviso</span>
              <span role="columnheader">Push</span>
              <span role="columnheader">En la app</span>
            </div>
            @for (preference of group.items; track preference.type) {
              <div class="pref" role="row">
                <span role="cell">{{ label(preference) }}</span>
                <span role="cell">
                  <ui-switch
                    [label]="'Push: ' + label(preference)"
                    [checked]="preference.push"
                    (checkedChange)="update(preference, 'push', $event)"
                  />
                </span>
                <span role="cell">
                  <ui-switch
                    [label]="'En la app: ' + label(preference)"
                    [checked]="preference.in_app"
                    (checkedChange)="update(preference, 'in_app', $event)"
                  />
                </span>
              </div>
            }
          </div>
        </ui-card>
      } @empty {
        <ui-card heading="Avisos">
          @if (loading()) {
            <ui-skeleton height="120px" />
          } @else {
            <p class="small faint">No hay tipos de aviso configurables.</p>
          }
        </ui-card>
      }
    </div>
  `,
  styles: `
    .strong {
      font-weight: 500;
    }
    .prefs {
      display: flex;
      flex-direction: column;
    }
    .pref {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 64px 72px;
      align-items: center;
      gap: 8px;
      min-height: 48px;
      border-bottom: 1px solid var(--border);
    }
    .pref:last-child {
      border-bottom: 0;
    }
    .pref.head {
      min-height: 32px;
    }
    .pref > span:not(:first-child) {
      display: flex;
      justify-content: center;
    }
  `,
})
export class NotificationSettings implements OnInit {
  protected readonly push = inject(PushService);
  private readonly store = inject(NotificationsStore);
  private readonly registry = inject(ModuleRegistry);
  private readonly toast = inject(ToastService);

  protected readonly preferences = signal<NotificationPreference[]>([]);
  protected readonly loading = signal(true);
  protected readonly testing = signal(false);
  protected readonly device = describeUserAgent(typeof navigator === 'undefined' ? null : navigator.userAgent);
  protected readonly pushStatusText = computed(() => {
    if (!this.push.supported) {
      return 'no disponible';
    }
    return this.push.subscribed() ? 'activadas' : 'desactivadas';
  });
  protected readonly groups = computed(() => {
    const byModule = new Map<string, NotificationPreference[]>();
    for (const preference of this.preferences()) {
      byModule.set(preference.module_id, [...(byModule.get(preference.module_id) ?? []), preference]);
    }
    return [...byModule.entries()].map(([moduleId, items]) => ({
      moduleId,
      name: items[0]?.module_name ?? this.registry.manifest(moduleId as never)?.name ?? moduleId,
      items,
    }));
  });

  async ngOnInit(): Promise<void> {
    try {
      this.preferences.set(await this.store.preferences());
    } catch {
      this.preferences.set([]);
    } finally {
      this.loading.set(false);
    }
  }

  protected label(preference: NotificationPreference): string {
    return notificationTypeLabel(preference);
  }

  protected async update(preference: NotificationPreference, channel: 'push' | 'in_app', value: boolean): Promise<void> {
    const previous = this.preferences();
    const next = previous.map((item) =>
      item.module_id === preference.module_id && item.type === preference.type ? { ...item, [channel]: value } : item,
    );
    this.preferences.set(next);
    try {
      await this.store.savePreferences(next);
    } catch {
      this.preferences.set(previous);
      this.toast.error('No se han podido guardar las preferencias');
    }
  }

  protected async enable(): Promise<void> {
    try {
      await this.push.enable();
      this.toast.show('Notificaciones activadas en este dispositivo');
    } catch {
      this.toast.error('No se han podido activar las notificaciones');
    }
  }

  protected async disable(): Promise<void> {
    try {
      await this.push.disable();
      this.toast.show('Notificaciones desactivadas en este dispositivo');
    } catch {
      this.toast.error('No se han podido desactivar las notificaciones');
    }
  }

  protected async sendTest(): Promise<void> {
    this.testing.set(true);
    try {
      await this.push.sendTest();
      this.toast.show('Notificación de prueba enviada');
    } catch {
      this.toast.error('No se ha podido enviar la prueba');
    } finally {
      this.testing.set(false);
    }
  }
}
