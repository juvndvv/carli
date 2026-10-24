import { ChangeDetectionStrategy, Component, computed, inject, input, resource } from '@angular/core';
import { RouterLink } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { GoalContribution, goalPercent, goalTargetMonthLabel, SavingsGoal } from '@finance/data-access/goals.models';
import { GoalsService } from '@finance/data-access/goals.service';
import { formatShortDate } from '@shared/dates/dates';
import { RelativeDatePipe } from '@shared/dates/relative-date.pipe';
import { formatMoney } from '@shared/money/money';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiProgress } from '@ui/progress/progress';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { ContributionDialog, ContributionDialogData } from './contribution-dialog';
import { GoalDialog, GoalDialogData } from './goal-dialog';

@Component({
  selector: 'app-finance-goal-detail-page',
  imports: [
    UiPageHeader,
    UiCard,
    UiEmptyState,
    UiButton,
    UiBadge,
    UiIcon,
    UiProgress,
    UiStat,
    UiListItem,
    UiSkeleton,
    MoneyPipe,
    RelativeDatePipe,
    RouterLink,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header [heading]="goal()?.name ?? 'Objetivo'" crumb="Finanzas · Objetivos" backLink="/finanzas/objetivos">
      @if (goal(); as current) {
        <button ui-button variant="secondary" size="sm" icon="pencil" aria-label="Editar objetivo" (click)="edit(current)">
          <span class="d-only">Editar</span>
        </button>
        @if (!current.account_id) {
          <button ui-button variant="primary" size="sm" icon="plus" aria-label="Aportar" (click)="contribute(current)">
            <span class="d-only">Aportar</span>
          </button>
        }
      }
    </ui-page-header>

    @if (goalResource.isLoading() && !goal()) {
      <ui-card>
        <div class="stack">
          <ui-skeleton width="40%" height="42px" />
          <ui-skeleton height="8px" radius="999px" />
          <ui-skeleton width="60%" />
        </div>
      </ui-card>
    } @else if (goalResource.error() && !goal()) {
      <ui-card>
        <ui-empty-state icon="circle-alert" heading="No encontramos este objetivo" description="Puede que se haya eliminado.">
          <a ui-button size="sm" routerLink="/finanzas/objetivos">Volver a objetivos</a>
        </ui-empty-state>
      </ui-card>
    } @else if (goal(); as current) {
      <div class="stack">
        <ui-card>
          <div class="row between hero-head">
            <div class="row">
              <span class="ico"><ui-icon [name]="current.icon || 'piggy-bank'" /></span>
              <span class="caption">{{ current.account ? 'Saldo de ' + current.account.name : 'Ahorrado' }}</span>
            </div>
            <ui-badge [tone]="current.achieved ? 'positive' : 'neutral'" [icon]="current.achieved ? 'check' : null">
              {{ current.achieved ? 'Conseguido' : percent() + ' %' }}
            </ui-badge>
          </div>
          <div class="hero num">
            <span class="display">{{ current.saved_cents | money }}</span>
            <span class="muted">de {{ current.target_cents | money }}</span>
          </div>
          <ui-progress tone="primary" [ratio]="current.progress_bp / 10000" [label]="'Progreso de ' + current.name" />
          @if (current.account) {
            <p class="small faint linked">
              <ui-icon name="link" [size]="13" />
              El progreso es el saldo de
              <a [routerLink]="['/finanzas/cuentas', current.account.id]">{{ current.account.name }}</a>.
              Para aportar, haz una transferencia a esa cuenta.
            </p>
          }
        </ui-card>

        <div class="grid-cards g-3">
          <ui-stat label="Te falta" icon="target" [value]="remainingLabel()" [tone]="current.achieved ? 'positive' : 'default'" />
          <ui-stat
            label="Aportación mensual"
            icon="calendar"
            [value]="monthlyLabel()"
            [delta]="monthsLeftLabel()"
          />
          <ui-stat label="Fecha objetivo" icon="calendar-days" [value]="targetLabel()" [delta]="targetDelta()" />
        </div>

        @if (!current.account_id) {
          <ui-card heading="Aportaciones" padding="list">
            @if (contributionsResource.isLoading() && !contributions().length) {
              <div class="pad"><ui-skeleton /></div>
            } @else if (contributions().length === 0) {
              <ui-empty-state
                icon="piggy-bank"
                heading="Sin aportaciones todavía"
                description="Cada vez que apartes dinero para este objetivo, regístralo aquí."
              >
                <button ui-button variant="primary" size="sm" icon="plus" (click)="contribute(current)">Aportar</button>
              </ui-empty-state>
            } @else {
              <div class="ui-list">
                @for (item of contributions(); track item.id) {
                  <ui-list-item
                    [heading]="item.note || (item.amount_cents > 0 ? 'Aportación' : 'Retirada')"
                    [subtitle]="item.date | relativeDate: 'title'"
                    [icon]="item.amount_cents > 0 ? 'plus' : 'minus'"
                    iconSoft
                  >
                    <span trailing class="trail">
                      <span class="num value" [class.pos]="item.amount_cents > 0">{{ item.amount_cents | money: 'signed' }}</span>
                      <button
                        ui-button
                        variant="ghost"
                        size="sm"
                        icon="trash"
                        iconOnly
                        [attr.aria-label]="'Borrar aportación del ' + shortDate(item)"
                        (click)="removeContribution(current, item)"
                      ></button>
                    </span>
                  </ui-list-item>
                }
              </div>
            }
          </ui-card>
        }
      </div>
    }
  `,
  styles: `
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: var(--surface-2);
      color: var(--text);
    }
    .hero-head {
      margin-bottom: 12px;
    }
    .hero {
      display: flex;
      align-items: baseline;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 14px;
    }
    .linked {
      margin-top: 12px;
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 4px;
    }
    .linked a {
      color: var(--text);
    }
    .trail {
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .value {
      font-weight: 550;
      white-space: nowrap;
    }
    .pad {
      padding: 12px 4px;
    }
  `,
})
export class GoalDetailPage {
  private readonly service = inject(GoalsService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);

  readonly id = input.required<string>();

  protected readonly goalResource = resource({
    params: () => this.id(),
    loader: ({ params }) => this.service.get(params),
  });
  protected readonly contributionsResource = resource({
    params: () => this.id(),
    loader: ({ params }) => this.service.contributions(params),
  });

  protected readonly goal = computed<SavingsGoal | undefined>(() =>
    this.goalResource.hasValue() ? this.goalResource.value() : undefined,
  );
  protected readonly contributions = computed<GoalContribution[]>(() =>
    this.contributionsResource.hasValue() ? this.contributionsResource.value() : [],
  );

  protected readonly percent = computed(() => {
    const goal = this.goal();
    return goal ? goalPercent(goal) : 0;
  });
  protected readonly remainingLabel = computed(() => {
    const goal = this.goal();
    if (!goal) {
      return '';
    }
    return goal.remaining_cents === 0 ? 'Nada, ¡lo tienes!' : formatMoney(goal.remaining_cents);
  });
  protected readonly monthlyLabel = computed(() => {
    const goal = this.goal();
    if (!goal || goal.achieved || goal.remaining_cents === 0) {
      return '—';
    }
    return goal.monthly_needed_cents ? `${formatMoney(goal.monthly_needed_cents)}/mes` : 'Sin fecha límite';
  });
  protected readonly monthsLeftLabel = computed(() => {
    const months = this.goal()?.months_left;
    if (months === null || months === undefined || this.goal()?.achieved) {
      return null;
    }
    return months === 1 ? 'Durante 1 mes' : `Durante ${months} meses`;
  });
  protected readonly targetLabel = computed(() => goalTargetMonthLabel(this.goal()?.target_date ?? null) ?? 'Sin fecha');
  protected readonly targetDelta = computed(() => {
    const date = this.goal()?.target_date;
    return date ? formatShortDate(date, true) : 'Ahorra a tu ritmo';
  });

  protected shortDate(item: GoalContribution): string {
    return formatShortDate(item.date);
  }

  protected async edit(goal: SavingsGoal): Promise<void> {
    const ref = this.dialogs.open<GoalDialog, GoalDialogData, SavingsGoal | 'deleted'>(GoalDialog, { data: { goal } });
    const result = await firstValueFrom(ref.closed);
    if (result && result !== 'deleted') {
      this.goalResource.set(result);
      this.contributionsResource.reload();
    }
  }

  protected async contribute(goal: SavingsGoal): Promise<void> {
    const ref = this.dialogs.open<ContributionDialog, ContributionDialogData>(ContributionDialog, { data: { goal } });
    const result = await firstValueFrom(ref.closed);
    if (result) {
      this.reload();
    }
  }

  protected async removeContribution(goal: SavingsGoal, item: GoalContribution): Promise<void> {
    try {
      await this.service.removeContribution(goal.id, item.id);
      this.reload();
      this.toast.withUndo('Aportación borrada', async () => {
        await this.service.contribute(goal.id, { amount_cents: item.amount_cents, date: item.date, note: item.note });
        this.reload();
      });
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido borrar la aportación.'));
    }
  }

  private reload(): void {
    this.goalResource.reload();
    this.contributionsResource.reload();
    void this.service.load();
  }
}
