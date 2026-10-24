import { CdkMenu, CdkMenuItem, CdkMenuTrigger } from '@angular/cdk/menu';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import {
  filterRecurringRules,
  frequencyLabel,
  RecurringRule,
  RecurringTab,
  reminderLabel,
  upcomingCharges,
} from '@finance/data-access/recurring.models';
import { RecurringService } from '@finance/data-access/recurring.service';
import { daysBetween, formatShortDate, formatRelativeDay, todayIso } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { UiTab, UiTabs } from '@ui/tabs/tabs';
import { ToastService } from '@ui/toast/toast.service';
import { ConfirmOccurrenceDialog, ConfirmOccurrenceDialogData } from './confirm-occurrence-dialog';
import { RecurringRuleDialog, RecurringRuleDialogData } from './recurring-rule-dialog';

const EMPTY_COPY: Record<RecurringTab, { heading: string; description: string }> = {
  all: {
    heading: 'Aún no tienes recurrentes',
    description: 'Añade el alquiler, la nómina o tus suscripciones y te avisaremos antes de cada cargo.',
  },
  subscriptions: {
    heading: 'Sin suscripciones',
    description: 'Marca un recurrente como suscripción para ver aquí cuánto te cuestan al mes y al año.',
  },
  pending: {
    heading: 'Nada pendiente de confirmar',
    description: 'Los cargos con confirmación aparecerán aquí el día que toquen.',
  },
  cancelled: {
    heading: 'Sin suscripciones canceladas',
    description: 'Cuando canceles un recurrente lo verás aquí y podrás reactivarlo.',
  },
};

@Component({
  selector: 'app-finance-recurring-page',
  imports: [
    UiPageHeader,
    UiCard,
    UiEmptyState,
    UiButton,
    UiTabs,
    UiStat,
    UiListItem,
    UiBadge,
    UiSkeleton,
    MoneyPipe,
    CdkMenuTrigger,
    CdkMenu,
    CdkMenuItem,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Recurrentes" crumb="Finanzas">
      <button ui-button variant="primary" size="sm" icon="plus" aria-label="Nuevo recurrente" (click)="create()">
        <span class="d-only">Nuevo recurrente</span>
      </button>
    </ui-page-header>

    <ui-tabs [tabs]="tabs()" [(active)]="activeTab" ariaLabel="Filtrar recurrentes" />

    <div class="grid-cards g-3 stats">
      <ui-stat
        label="Suscripciones al mes"
        icon="repeat"
        [value]="subscriptionsMonthly()"
        [delta]="subscriptionsCountLabel()"
      />
      <ui-stat label="Al año" icon="calendar" [value]="subscriptionsYearly()" />
      <ui-stat
        label="Aviso"
        icon="bell"
        [value]="reminder()"
        delta="Notificación push a las 09:00"
        class="reminder"
      />
    </div>

    @if (activeTab() === 'subscriptions' && upcoming().length) {
      <ui-card heading="Próximos cargos" padding="list" class="block">
        <div class="ui-list">
          @for (rule of upcoming(); track rule.id) {
            <ui-list-item
              [heading]="rule.name"
              [subtitle]="upcomingLabel(rule)"
              [icon]="ruleIcon(rule)"
              [value]="rule.amount_cents | money: 'signed'"
              [valueTone]="rule.amount_cents > 0 ? 'positive' : 'default'"
            />
          }
        </div>
      </ui-card>
    }

    <ui-card padding="list" class="block">
      @if (service.loading() && !service.loaded()) {
        <div class="ui-list" aria-busy="true">
          @for (row of skeletonRows; track row) {
            <div class="skeleton-row">
              <ui-skeleton width="36px" height="36px" radius="999px" />
              <div class="grow"><ui-skeleton width="45%" /><ui-skeleton width="30%" height="12px" /></div>
              <ui-skeleton width="72px" />
            </div>
          }
        </div>
      } @else if (service.error() && !service.loaded()) {
        <ui-empty-state icon="circle-alert" heading="No se han podido cargar" [description]="service.error()">
          <button ui-button size="sm" icon="refresh-cw" (click)="service.load()">Reintentar</button>
        </ui-empty-state>
      } @else if (visible().length === 0) {
        <ui-empty-state icon="repeat" [heading]="emptyCopy().heading" [description]="emptyCopy().description">
          @if (activeTab() === 'all' || activeTab() === 'subscriptions') {
            <button ui-button variant="primary" size="sm" icon="plus" (click)="create()">Nuevo recurrente</button>
          }
        </ui-empty-state>
      } @else {
        <div class="ui-list">
          @for (rule of visible(); track rule.id) {
            <ui-list-item
              interactive
              [heading]="rule.name"
              [subtitle]="subtitle(rule)"
              [icon]="ruleIcon(rule)"
              (click)="edit(rule)"
            >
              <span badges>
                @if (rule.is_subscription) {
                  <ui-badge>Suscripción</ui-badge>
                }
                @if (rule.pending_transaction) {
                  <ui-badge tone="warning" icon="clock">Pendiente</ui-badge>
                }
                @if (rule.cancelled) {
                  <ui-badge icon="circle-x">Cancelada</ui-badge>
                }
                @if (rule.debt_id) {
                  <ui-badge icon="hand-coins">Préstamo</ui-badge>
                }
              </span>
              <span trailing class="trail">
                @if (!rule.cancelled) {
                  <ui-badge class="d-only" [tone]="rule.mode === 'auto' ? 'neutral' : 'primary'" [icon]="rule.mode === 'auto' ? 'zap' : 'hand'">
                    {{ rule.mode === 'auto' ? 'Automático' : 'Con confirmación' }}
                  </ui-badge>
                }
                <span class="value num" [class.pos]="rule.amount_cents > 0" [class.muted]="rule.cancelled">
                  {{ rule.amount_cents | money: 'signed' }}
                </span>
                @if (rule.pending_transaction) {
                  <button
                    ui-button
                    size="sm"
                    variant="secondary"
                    icon="check"
                    [attr.aria-label]="'Confirmar cargo de ' + rule.name"
                    (click)="$event.stopPropagation(); confirm(rule)"
                  >
                    <span class="d-only">Confirmar</span>
                  </button>
                }
                <button
                  ui-button
                  variant="ghost"
                  size="sm"
                  icon="ellipsis"
                  iconOnly
                  [attr.aria-label]="'Acciones de ' + rule.name"
                  [cdkMenuTriggerFor]="menu"
                  (click)="$event.stopPropagation()"
                ></button>
                <ng-template #menu>
                  <div cdkMenu class="ui-menu">
                    <button cdkMenuItem class="ui-menu-item" (cdkMenuItemTriggered)="edit(rule)">Editar</button>
                    @if (!rule.cancelled && (rule.pending_transaction || rule.next_occurrence)) {
                      <button cdkMenuItem class="ui-menu-item" (cdkMenuItemTriggered)="confirm(rule)">
                        {{ rule.pending_transaction ? 'Confirmar cargo pendiente' : 'Registrar el próximo cargo ya' }}
                      </button>
                    }
                    @if (rule.cancelled) {
                      <button cdkMenuItem class="ui-menu-item" (cdkMenuItemTriggered)="setCancelled(rule, false)">Reactivar</button>
                    } @else {
                      <button cdkMenuItem class="ui-menu-item" (cdkMenuItemTriggered)="setCancelled(rule, true)">
                        {{ rule.is_subscription ? 'Cancelar suscripción' : 'Cancelar recurrente' }}
                      </button>
                    }
                  </div>
                </ng-template>
              </span>
            </ui-list-item>
          }
        </div>
      }
    </ui-card>
  `,
  styles: `
    .block {
      margin-top: 16px;
    }
    .trail {
      display: flex;
      align-items: center;
      gap: 8px;
      flex: none;
    }
    .value {
      font-weight: 550;
      min-width: 96px;
      text-align: right;
      white-space: nowrap;
    }
    .skeleton-row {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 4px;
    }
    .grow {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    @media (max-width: 1023px) {
      .stats {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
      .reminder {
        display: none;
      }
    }
    @media (max-width: 640px) {
      .value {
        min-width: 0;
      }
    }
  `,
})
export class RecurringPage implements OnInit {
  protected readonly service = inject(RecurringService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);

  protected readonly activeTab = signal<RecurringTab>('all');
  protected readonly skeletonRows = [0, 1, 2, 3];
  protected readonly today = signal(todayIso());

  protected readonly tabs = computed<UiTab[]>(() => [
    { id: 'all', label: 'Todos' },
    { id: 'subscriptions', label: 'Suscripciones' },
    { id: 'pending', label: 'Pendientes de confirmar', badge: this.service.pendingCount() || null },
    { id: 'cancelled', label: 'Canceladas' },
  ]);

  protected readonly visible = computed(() => filterRecurringRules(this.service.rules(), this.activeTab()));
  protected readonly upcoming = computed(() =>
    upcomingCharges(this.service.subscriptions(), this.today(), 30).slice(0, 5),
  );
  protected readonly emptyCopy = computed(() => EMPTY_COPY[this.activeTab()]);

  protected readonly subscriptionsMonthly = computed(() => formatMoney(this.service.meta()?.subscriptions.monthly_cents ?? 0));
  protected readonly subscriptionsYearly = computed(() => formatMoney(this.service.meta()?.subscriptions.yearly_cents ?? 0));
  protected readonly subscriptionsCountLabel = computed(() => {
    const count = this.service.meta()?.subscriptions.count ?? 0;
    return count === 1 ? '1 activa' : `${count} activas`;
  });
  protected readonly reminder = computed(() => {
    const days = this.service.reminderDays();
    return days === null ? '—' : reminderLabel(days);
  });

  ngOnInit(): void {
    void this.service.load();
    void this.service.loadReminderSettings();
  }

  protected subtitle(rule: RecurringRule): string {
    const parts = [frequencyLabel(rule)];
    if (rule.pending_transaction) {
      parts.push(`pendiente del ${formatShortDate(rule.pending_transaction.date)}`);
    } else if (rule.next_occurrence && !rule.cancelled) {
      parts.push(`próximo ${formatShortDate(rule.next_occurrence)}`);
    } else if (!rule.next_occurrence && !rule.cancelled) {
      parts.push('finalizado');
    }
    return parts.join(' · ');
  }

  protected upcomingLabel(rule: RecurringRule): string {
    const date = rule.next_occurrence!;
    const days = daysBetween(this.today(), date);
    const relative = formatRelativeDay(date, this.today(), 'title');
    if (days <= 1) {
      return `${relative} · ${rule.account.name}`;
    }
    return `${relative} · en ${days} días · ${rule.account.name}`;
  }

  protected ruleIcon(rule: RecurringRule): string {
    return rule.category?.icon ?? (rule.kind === 'income' ? 'briefcase' : 'repeat');
  }

  protected create(): void {
    this.dialogs.open<RecurringRuleDialog, RecurringRuleDialogData>(RecurringRuleDialog, {
      data: { rule: null, isSubscription: this.activeTab() === 'subscriptions' },
    });
  }

  protected edit(rule: RecurringRule): void {
    this.dialogs.open<RecurringRuleDialog, RecurringRuleDialogData>(RecurringRuleDialog, { data: { rule } });
  }

  protected confirm(rule: RecurringRule): void {
    this.dialogs.open<ConfirmOccurrenceDialog, ConfirmOccurrenceDialogData>(ConfirmOccurrenceDialog, { data: { rule } });
  }

  protected async setCancelled(rule: RecurringRule, cancelled: boolean): Promise<void> {
    try {
      await this.service.setCancelled(rule.id, cancelled);
      if (cancelled) {
        this.toast.withUndo(`${rule.name} cancelada`, () => this.setCancelled(rule, false));
      } else {
        this.toast.show(`${rule.name} reactivada`);
      }
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido actualizar el recurrente.'));
    }
  }
}
