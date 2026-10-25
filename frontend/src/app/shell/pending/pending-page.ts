import { ChangeDetectionStrategy, Component, computed, effect, inject, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router } from '@angular/router';
import { PendingActions } from '@core/pending/pending-actions';
import {
  PendingFilter,
  PendingItem,
  PendingSummaryEntry,
  PendingTypeDescriptor,
  PENDING_QUERY,
  pendingTotalLabel,
} from '@core/pending/pending.models';
import { PendingStore } from '@core/pending/pending.store';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiChip } from '@ui/chip/chip';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { AppPendingItemRow } from './pending-item-row';

export interface PendingTypeGroup {
  type: string;
  descriptor: PendingTypeDescriptor;
  count: number;
  route: string;
  items: PendingItem[];
}

export interface PendingModuleGroup {
  module: string;
  name: string;
  icon: string;
  types: PendingTypeGroup[];
}

export function groupPendingItems(
  items: PendingItem[],
  entries: PendingSummaryEntry[],
  describe: (module: string, type: string) => PendingTypeDescriptor,
  moduleInfo: (module: string) => { name: string | null; icon: string },
): PendingModuleGroup[] {
  const groups: PendingModuleGroup[] = [];
  for (const item of items) {
    let group = groups.find((current) => current.module === item.module);
    if (!group) {
      const info = moduleInfo(item.module);
      const name = info.name ?? entries.find((entry) => entry.module === item.module)?.module_name ?? item.module;
      group = { module: item.module, name, icon: info.icon, types: [] };
      groups.push(group);
    }
    let typeGroup = group.types.find((current) => current.type === item.type);
    if (!typeGroup) {
      const entry = entries.find((current) => current.module === item.module && current.type === item.type);
      typeGroup = { type: item.type, descriptor: describe(item.module, item.type), count: entry?.count ?? 0, route: item.route, items: [] };
      group.types.push(typeGroup);
    }
    typeGroup.items.push(item);
  }
  for (const typeGroup of groups.flatMap((group) => group.types)) {
    typeGroup.count = Math.max(typeGroup.count, typeGroup.items.length);
  }
  return groups;
}

@Component({
  selector: 'app-pending-page',
  imports: [UiPageHeader, UiCard, UiChip, UiBadge, UiButton, UiIcon, UiEmptyState, UiSkeleton, AppPendingItemRow],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Pendientes" [crumb]="crumb()" />

    <div class="stack page">
      @if (store.entries().length > 1 || isFiltered()) {
        <div class="hscroll chips" role="toolbar" aria-label="Filtrar pendientes">
          <button ui-chip type="button" [selected]="!isFiltered()" (click)="select(null, null)">Todo ({{ store.total() }})</button>
          @for (entry of store.entries(); track entry.module + entry.type) {
            <button
              ui-chip
              type="button"
              [icon]="describe(entry).icon"
              [selected]="filter().module === entry.module && filter().type === entry.type"
              (click)="select(entry.module, entry.type)"
            >
              {{ describe(entry).label }} ({{ entry.count }})
            </button>
          }
        </div>
      }

      @if (store.listError() && store.items().length === 0) {
        <ui-card>
          <ui-empty-state icon="circle-alert" heading="No se han podido cargar los pendientes" [description]="store.listError()">
            <button ui-button type="button" variant="secondary" (click)="reload()">Reintentar</button>
          </ui-empty-state>
        </ui-card>
      } @else if (!store.listLoaded()) {
        <ui-card padding="list">
          @for (row of skeletonRows; track row) {
            <div class="skeleton-row">
              <ui-skeleton width="36px" height="36px" radius="999px" />
              <div class="skeleton-body">
                <ui-skeleton width="45%" height="14px" />
                <ui-skeleton width="30%" height="12px" />
              </div>
            </div>
          }
        </ui-card>
      } @else if (groups().length === 0) {
        <ui-card>
          @if (isFiltered()) {
            <ui-empty-state icon="circle-check" heading="Nada pendiente de este tipo" description="Ya lo has revisado todo en esta sección.">
              <button ui-button type="button" variant="secondary" (click)="select(null, null)">Ver todos los pendientes</button>
            </ui-empty-state>
          } @else {
            <ui-empty-state
              icon="circle-check"
              heading="Todo al día"
              description="Aquí aparecerá lo que necesite tu atención, como movimientos sin categoría o recurrentes por confirmar."
            />
          }
        </ui-card>
      } @else {
        @for (group of groups(); track group.module) {
          <section class="stack module" [attr.aria-label]="group.name">
            @if (groups().length > 1 || !isFiltered()) {
              <h2 class="row module-head">
                <ui-icon [name]="group.icon" />
                {{ group.name }}
              </h2>
            }
            @for (typeGroup of group.types; track typeGroup.type) {
              <ui-card padding="list" [heading]="typeGroup.descriptor.label">
                <span card-actions class="row head-actions">
                  <ui-badge tone="warning">{{ typeGroup.count }}</ui-badge>
                  <button ui-button type="button" variant="ghost" size="sm" (click)="open(typeGroup.route)">Ver todos</button>
                </span>
                <div class="ui-list">
                  @for (item of typeGroup.items; track item.id) {
                    <app-pending-item-row [item]="item" />
                  }
                </div>
              </ui-card>
            }
          </section>
        }
        @if (store.hasMore()) {
          <div class="more">
            <button ui-button type="button" variant="ghost" size="sm" [loading]="store.listLoading()" (click)="store.loadMore()">
              Cargar más
            </button>
          </div>
        }
      }
    </div>
  `,
  styles: `
    .page {
      gap: 16px;
    }
    .chips {
      margin: 0 -2px;
      padding: 2px;
    }
    .module {
      gap: 12px;
    }
    .module-head {
      gap: 8px;
      margin: 4px 4px 0;
    }
    .head-actions {
      gap: 4px;
    }
    .skeleton-row {
      display: flex;
      align-items: center;
      gap: 12px;
      min-height: 56px;
      padding: 10px 4px;
    }
    .skeleton-body {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .more {
      display: flex;
      justify-content: center;
    }
  `,
})
export class PendingPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly actions = inject(PendingActions);
  protected readonly store = inject(PendingStore);

  protected readonly skeletonRows = [1, 2, 3, 4];
  private readonly queryParams = toSignal(this.route.queryParamMap, { initialValue: this.route.snapshot.queryParamMap });
  protected readonly filter = computed<PendingFilter>(() => {
    const params = this.queryParams();
    return { module: params.get(PENDING_QUERY.module) || null, type: params.get(PENDING_QUERY.type) || null };
  });
  protected readonly isFiltered = computed(() => this.filter().module !== null || this.filter().type !== null);
  protected readonly groups = computed(() =>
    groupPendingItems(
      this.store.items(),
      this.store.entries(),
      (module, type) => this.actions.describe(module, type),
      (module) => {
        const manifest = this.actions.manifest(module);
        return { name: manifest?.name ?? null, icon: manifest?.icon ?? 'inbox' };
      },
    ),
  );
  protected readonly crumb = computed(() => {
    if (!this.store.summaryLoaded()) {
      return 'Todo lo que requiere tu atención';
    }
    return pendingTotalLabel(this.store.total());
  });

  constructor() {
    effect(() => {
      const filter = this.filter();
      untracked(() => void this.store.load(filter));
    });
  }

  protected describe(entry: PendingSummaryEntry): PendingTypeDescriptor {
    return this.actions.describe(entry.module, entry.type);
  }

  protected select(module: string | null, type: string | null): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { [PENDING_QUERY.module]: module, [PENDING_QUERY.type]: type },
      replaceUrl: true,
    });
  }

  protected open(route: string): void {
    void this.router.navigateByUrl(route);
  }

  protected reload(): void {
    void this.store.load(this.filter());
  }
}
