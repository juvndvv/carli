import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { PendingActions } from '@core/pending/pending-actions';
import { PENDING_QUERY, pendingTotalLabel } from '@core/pending/pending.models';
import { PendingStore } from '@core/pending/pending.store';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiIcon } from '@ui/icon/icon';
import { UiListItem } from '@ui/list-item/list-item';

@Component({
  selector: 'app-pending-home-card',
  imports: [RouterLink, UiCard, UiButton, UiIcon, UiListItem],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (store.total() > 0) {
      <ui-card padding="list" heading="Pendientes">
        <a card-actions ui-button variant="ghost" size="sm" routerLink="/pendientes">Revisar</a>
        <p class="small muted lead">{{ headline() }}</p>
        <div class="ui-list">
          @for (row of rows(); track row.key) {
            <a ui-list-item routerLink="/pendientes" [queryParams]="row.query" [heading]="row.label" [icon]="row.icon" iconSoft>
              <ui-icon trailing name="chevron-right" class="faint" />
            </a>
          }
        </div>
      </ui-card>
    }
  `,
  styles: `
    :host {
      display: block;
    }
    :host:empty {
      display: none;
    }
    .lead {
      margin: 0 4px 4px;
    }
  `,
})
export class AppPendingHomeCard {
  private readonly actions = inject(PendingActions);
  protected readonly store = inject(PendingStore);

  protected readonly headline = computed(() => pendingTotalLabel(this.store.total()));
  protected readonly rows = computed(() =>
    this.store.entries().map((entry) => {
      const descriptor = this.actions.describe(entry.module, entry.type);
      return {
        key: `${entry.module}:${entry.type}`,
        label: descriptor.countLabel(entry.count),
        icon: descriptor.icon,
        query: { [PENDING_QUERY.module]: entry.module, [PENDING_QUERY.type]: entry.type },
      };
    }),
  );
}
