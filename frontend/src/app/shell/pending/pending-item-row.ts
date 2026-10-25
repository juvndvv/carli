import { NgComponentOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject, input, resource } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { PendingActions } from '@core/pending/pending-actions';
import { PendingItem } from '@core/pending/pending.models';
import { formatRelativeDay } from '@shared/dates/dates';
import { formatMoney } from '@shared/money/money';
import { UiButton } from '@ui/button/button';
import { UiIcon } from '@ui/icon/icon';
import { UiSkeleton } from '@ui/skeleton/skeleton';

@Component({
  selector: 'app-pending-item-row',
  imports: [NgComponentOutlet, RouterLink, UiIcon, UiButton, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="main">
      <span class="ico"><ui-icon [name]="icon()" /></span>
      <span class="body">
        <span class="title">{{ item().title }}</span>
        <span class="subtitle">{{ subtitle() }}</span>
      </span>
      @if (amount(); as value) {
        <span class="value num" [class.pos]="(item().amount_cents ?? 0) > 0">{{ value }}</span>
      }
    </div>
    <div class="action">
      @if (action.value(); as component) {
        <ng-container *ngComponentOutlet="component; inputs: { item: item() }" />
      } @else if (action.isLoading()) {
        <ui-skeleton width="120px" height="32px" radius="999px" />
      } @else {
        <a ui-button variant="secondary" size="sm" trailingIcon="chevron-right" [routerLink]="link()">Revisar</a>
      }
    </div>
  `,
  styles: `
    :host {
      display: block;
      padding: 12px 4px;
      border-bottom: 1px solid var(--border);
    }
    :host(:last-child) {
      border-bottom: 0;
    }
    .main {
      display: flex;
      align-items: center;
      gap: 12px;
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
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .subtitle {
      font-size: 13px;
      line-height: 18px;
      color: var(--text-2);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .value {
      font-weight: 500;
      white-space: nowrap;
    }
    .value.pos {
      color: var(--positive);
    }
    .action {
      margin-top: 8px;
      padding-left: 48px;
    }
  `,
})
export class AppPendingItemRow {
  private readonly actions = inject(PendingActions);
  private readonly router = inject(Router);

  readonly item = input.required<PendingItem>();

  protected readonly icon = computed(() => this.actions.describe(this.item().module, this.item().type).icon);
  protected readonly amount = computed(() => {
    const cents = this.item().amount_cents;
    return cents === null ? null : formatMoney(cents, 'signed');
  });
  protected readonly subtitle = computed(() =>
    [formatRelativeDay(this.item().date, undefined, 'title'), this.item().subtitle].filter(Boolean).join(' · '),
  );
  protected readonly link = computed(() => this.router.parseUrl(this.item().route));

  protected readonly action = resource({
    params: () => ({ module: this.item().module, type: this.item().type }),
    loader: ({ params }) => this.actions.action(params.module, params.type),
  });
}
