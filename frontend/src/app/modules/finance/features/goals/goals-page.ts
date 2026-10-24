import { ChangeDetectionStrategy, Component, inject, OnInit } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { goalPercent, goalTargetMonthLabel, SavingsGoal } from '@finance/data-access/goals.models';
import { GoalsService } from '@finance/data-access/goals.service';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiProgress } from '@ui/progress/progress';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ContributionDialog, ContributionDialogData } from './contribution-dialog';
import { GoalDialog, GoalDialogData } from './goal-dialog';

@Component({
  selector: 'app-finance-goals-page',
  imports: [UiPageHeader, UiCard, UiEmptyState, UiButton, UiBadge, UiIcon, UiProgress, UiSkeleton, MoneyPipe, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Objetivos de ahorro" crumb="Finanzas">
      <button ui-button variant="primary" size="sm" icon="plus" aria-label="Nuevo objetivo" (click)="create()">
        <span class="d-only">Nuevo objetivo</span>
      </button>
    </ui-page-header>

    @if (service.loading() && !service.loaded()) {
      <div class="grid-cards g-3" aria-busy="true">
        @for (item of skeletons; track item) {
          <ui-card>
            <div class="stack">
              <ui-skeleton width="36px" height="36px" radius="999px" />
              <ui-skeleton width="60%" height="20px" />
              <ui-skeleton height="8px" radius="999px" />
            </div>
          </ui-card>
        }
      </div>
    } @else if (service.error() && !service.loaded()) {
      <ui-card>
        <ui-empty-state icon="circle-alert" heading="No se han podido cargar" [description]="service.error()">
          <button ui-button size="sm" icon="refresh-cw" (click)="service.load()">Reintentar</button>
        </ui-empty-state>
      </ui-card>
    } @else if (service.goals().length === 0) {
      <ui-card>
        <ui-empty-state
          icon="target"
          heading="Aún no tienes objetivos"
          description="Ponle nombre y cifra a lo que quieres conseguir y te diremos cuánto apartar cada mes."
        >
          <button ui-button variant="primary" size="sm" icon="plus" (click)="create()">Nuevo objetivo</button>
        </ui-empty-state>
      </ui-card>
    } @else {
      <div class="grid-cards g-3">
        @for (goal of service.goals(); track goal.id) {
          <ui-card interactive (click)="open(goal)">
            <div class="row between">
              <span class="ico"><ui-icon [name]="goal.icon || 'piggy-bank'" /></span>
              <ui-badge [tone]="goal.achieved ? 'positive' : 'neutral'" [icon]="goal.achieved ? 'check' : null">
                {{ percent(goal) }} %
              </ui-badge>
            </div>
            <h2 class="name">
              <a [routerLink]="['/finanzas/objetivos', goal.id]" (click)="$event.stopPropagation()">{{ goal.name }}</a>
            </h2>
            <div class="num amounts">
              <b>{{ goal.saved_cents | money }}</b> <span class="muted">de {{ goal.target_cents | money }}</span>
            </div>
            <ui-progress
              class="bar"
              tone="primary"
              [ratio]="goal.progress_bp / 10000"
              [label]="'Progreso de ' + goal.name"
            />
            <div class="small muted meta">
              @if (goal.achieved) {
                Objetivo conseguido
              } @else if (goal.target_date) {
                Meta: {{ targetLabel(goal) }}
                @if (goal.monthly_needed_cents) {
                  · aporta <b class="num strong">{{ goal.monthly_needed_cents | money }}/mes</b>
                }
              } @else {
                Sin fecha límite
              }
            </div>
            @if (goal.account) {
              <div class="small faint linked">
                <ui-icon name="link" [size]="13" /> Vinculado a la cuenta {{ goal.account.name }}
              </div>
            }
            <div class="row actions">
              @if (goal.account) {
                <a
                  ui-button
                  size="sm"
                  variant="secondary"
                  icon="landmark"
                  [routerLink]="['/finanzas/cuentas', goal.account.id]"
                  (click)="$event.stopPropagation()"
                >
                  Ver cuenta
                </a>
              } @else {
                <button ui-button size="sm" variant="secondary" icon="plus" (click)="$event.stopPropagation(); contribute(goal)">
                  Aportar
                </button>
              }
            </div>
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
    .name {
      margin-top: 14px;
    }
    .name a {
      color: inherit;
      text-decoration: none;
    }
    .name a:hover {
      text-decoration: underline;
    }
    .amounts {
      margin-top: 4px;
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      column-gap: 6px;
    }
    .amounts b {
      font-size: 20px;
      font-weight: 600;
    }
    .bar {
      margin-top: 12px;
    }
    .meta {
      margin-top: 10px;
    }
    .strong {
      color: var(--text);
    }
    .linked {
      margin-top: 4px;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .actions {
      margin-top: 14px;
    }
  `,
})
export class GoalsPage implements OnInit {
  protected readonly service = inject(GoalsService);
  private readonly dialogs = inject(DialogService);
  private readonly router = inject(Router);

  protected readonly skeletons = [0, 1, 2];

  ngOnInit(): void {
    void this.service.load();
  }

  protected percent(goal: SavingsGoal): number {
    return goalPercent(goal);
  }

  protected targetLabel(goal: SavingsGoal): string {
    return goalTargetMonthLabel(goal.target_date) ?? '';
  }

  protected open(goal: SavingsGoal): void {
    void this.router.navigate(['/finanzas/objetivos', goal.id]);
  }

  protected create(): void {
    this.dialogs.open<GoalDialog, GoalDialogData>(GoalDialog, { data: { goal: null } });
  }

  protected contribute(goal: SavingsGoal): void {
    this.dialogs.open<ContributionDialog, ContributionDialogData>(ContributionDialog, { data: { goal } });
  }
}
