import { CdkMenu, CdkMenuItem, CdkMenuTrigger } from '@angular/cdk/menu';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiIcon } from '@ui/icon/icon';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiTab, UiTabs } from '@ui/tabs/tabs';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { CategoriesService, FALLBACK_CATEGORY_ICON } from '../../data-access/categories.service';
import { Category, CategoryKind, Tag } from '../../data-access/finance.models';
import { TagsService } from '../../data-access/tags.service';
import { CategoryFormData, CategoryFormDialog } from './category-form-dialog';
import { DeleteCategoryData, DeleteCategoryDialog } from './delete-category-dialog';
import { MergeTagDialog, RenameTagDialog, TagDialogData } from './tag-dialogs';

type CategoriesView = 'expense' | 'income' | 'tags';

const VIEW_PARAMS: Record<string, CategoriesView> = { gastos: 'expense', ingresos: 'income', etiquetas: 'tags' };
const VIEW_TO_PARAM: Record<CategoriesView, string> = { expense: 'gastos', income: 'ingresos', tags: 'etiquetas' };

@Component({
  selector: 'app-finance-categories-page',
  imports: [
    UiPageHeader,
    UiTabs,
    UiCard,
    UiListItem,
    UiButton,
    UiBadge,
    UiIcon,
    UiSkeleton,
    UiEmptyState,
    CdkMenuTrigger,
    CdkMenu,
    CdkMenuItem,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Categorías y etiquetas" crumb="Finanzas">
      @if (view() !== 'tags') {
        <button ui-button type="button" variant="primary" size="sm" icon="plus" (click)="create()">
          <span class="d-only">Nueva categoría</span>
        </button>
      }
    </ui-page-header>

    <ui-tabs ariaLabel="Secciones" [tabs]="tabs()" [active]="view()" (activeChange)="setView($event)" />

    @if (view() === 'tags') {
      <ui-card padding="list">
        @if (!tags.loaded()) {
          <ui-skeleton height="56px" />
        } @else {
          <div class="ui-list">
            @for (tag of tags.all(); track tag.id) {
              <ui-list-item [heading]="'#' + tag.name" icon="hash" iconSoft [subtitle]="countLabel(tag.transactions_count)">
                <button
                  trailing
                  ui-button
                  type="button"
                  variant="ghost"
                  size="sm"
                  icon="ellipsis"
                  iconOnly
                  [attr.aria-label]="'Opciones de #' + tag.name"
                  [cdkMenuTriggerFor]="tagMenu"
                  [cdkMenuTriggerData]="{ $implicit: tag }"
                ></button>
              </ui-list-item>
            } @empty {
              <ui-empty-state
                icon="hash"
                heading="Aún no hay etiquetas"
                description="Añádelas al apuntar un movimiento (por ejemplo #vacaciones-2026) para agrupar gastos de distintas categorías."
              />
            }
          </div>
        }
      </ui-card>
    } @else {
      <ui-card padding="list">
        @if (!categories.loaded()) {
          <ui-skeleton height="56px" />
          <ui-skeleton height="56px" class="gap" />
        } @else {
          <div class="ui-list">
            @for (parent of visibleTree(); track parent.id) {
              <ui-list-item
                [heading]="parent.name"
                [icon]="parent.icon ?? fallbackIcon"
                [subtitle]="childrenLabel(parent)"
                [class.archived]="parent.archived"
              >
                @if (parent.opens_period || parent.archived) {
                <span badges class="badges">
                  @if (parent.opens_period) {
                    <ui-badge tone="primary" icon="calendar-range">Abre periodo</ui-badge>
                  }
                  @if (parent.archived) {
                    <ui-badge icon="archive">Archivada</ui-badge>
                  }
                </span>
                }
                <button
                  trailing
                  ui-button
                  type="button"
                  variant="ghost"
                  size="sm"
                  icon="ellipsis"
                  iconOnly
                  [attr.aria-label]="'Opciones de ' + parent.name"
                  [cdkMenuTriggerFor]="categoryMenu"
                  [cdkMenuTriggerData]="{ $implicit: parent, parent: null }"
                ></button>
              </ui-list-item>
              @for (child of parent.children; track child.id) {
                <ui-list-item
                  class="child"
                  [class.archived]="child.archived"
                  [heading]="child.name"
                  [icon]="child.icon ?? parent.icon ?? fallbackIcon"
                  iconSoft
                >
                  @if (child.opens_period || child.archived) {
                  <span badges class="badges">
                    @if (child.opens_period) {
                      <ui-badge tone="primary" icon="calendar-range">Abre periodo</ui-badge>
                    }
                    @if (child.archived) {
                      <ui-badge icon="archive">Archivada</ui-badge>
                    }
                  </span>
                  }
                  <button
                    trailing
                    ui-button
                    type="button"
                    variant="ghost"
                    size="sm"
                    icon="ellipsis"
                    iconOnly
                    [attr.aria-label]="'Opciones de ' + child.name"
                    [cdkMenuTriggerFor]="categoryMenu"
                    [cdkMenuTriggerData]="{ $implicit: child, parent: parent }"
                  ></button>
                </ui-list-item>
              }
            } @empty {
              <ui-empty-state icon="tag" heading="Sin categorías" description="Crea categorías para clasificar tus movimientos.">
                <button ui-button type="button" variant="primary" icon="plus" (click)="create()">Nueva categoría</button>
              </ui-empty-state>
            }
          </div>
        }
      </ui-card>
      @if (archivedCount() > 0) {
        <button type="button" class="archived-toggle small faint" (click)="showArchived.set(!showArchived())">
          <ui-icon name="archive" [size]="14" />
          {{ archivedCount() === 1 ? '1 archivada' : archivedCount() + ' archivadas' }} · {{ showArchived() ? 'ocultar' : 'mostrar' }}
        </button>
      }
    }

    <ng-template #categoryMenu let-category let-parent="parent">
      <div class="ui-menu" cdkMenu>
        <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="edit(category)"><ui-icon name="pencil" />Editar</button>
        @if (!parent) {
          <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="create(category.id)">
            <ui-icon name="plus" />Añadir subcategoría
          </button>
        }
        <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="setArchived(category, !category.archived)">
          <ui-icon [name]="category.archived ? 'archive-restore' : 'archive'" />{{ category.archived ? 'Desarchivar' : 'Archivar' }}
        </button>
        <button type="button" class="ui-menu-item danger" cdkMenuItem (cdkMenuItemTriggered)="remove(category)">
          <ui-icon name="trash" />Eliminar
        </button>
      </div>
    </ng-template>

    <ng-template #tagMenu let-tag>
      <div class="ui-menu" cdkMenu>
        <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="renameTag(tag)"><ui-icon name="pencil" />Renombrar</button>
        <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="mergeTag(tag)"><ui-icon name="git-merge" />Fusionar con…</button>
        <button type="button" class="ui-menu-item danger" cdkMenuItem (cdkMenuItemTriggered)="deleteTag(tag)"><ui-icon name="trash" />Eliminar</button>
      </div>
    </ng-template>
  `,
  styles: `
    .child {
      padding-left: 32px;
    }
    .archived {
      opacity: 0.6;
    }
    .badges {
      display: contents;
    }
    .gap {
      margin-top: 8px;
    }
    .archived-toggle {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      margin-top: 16px;
      border: 0;
      background: none;
      padding: 4px 0;
    }
  `,
})
export class CategoriesPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);
  protected readonly categories = inject(CategoriesService);
  protected readonly tags = inject(TagsService);
  protected readonly fallbackIcon = FALLBACK_CATEGORY_ICON;
  protected readonly showArchived = signal(false);

  private readonly params = toSignal(this.route.queryParamMap, { initialValue: this.route.snapshot.queryParamMap });
  protected readonly view = computed<CategoriesView>(() => VIEW_PARAMS[this.params().get('vista') ?? ''] ?? 'expense');
  protected readonly tabs = computed<UiTab[]>(() => [
    { id: 'expense', label: 'Gastos', badge: this.categories.topLevel('expense').length || null },
    { id: 'income', label: 'Ingresos', badge: this.categories.topLevel('income').length || null },
    { id: 'tags', label: 'Etiquetas', badge: this.tags.all().length || null },
  ]);
  private readonly kind = computed<CategoryKind>(() => (this.view() === 'income' ? 'income' : 'expense'));
  protected readonly visibleTree = computed(() =>
    this.categories
      .tree()
      .filter((category) => category.kind === this.kind() && (this.showArchived() || !category.archived))
      .map((category) => ({
        ...category,
        children: (category.children ?? []).filter((child) => this.showArchived() || !child.archived),
      })),
  );
  protected readonly archivedCount = computed(() =>
    this.categories.entries().filter((entry) => entry.category.kind === this.kind() && entry.category.archived).length,
  );

  protected setView(view: string | null): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { vista: view && view !== 'expense' ? VIEW_TO_PARAM[view as CategoriesView] : null },
      replaceUrl: true,
    });
  }

  protected childrenLabel(category: Category): string | null {
    const count = (category.children ?? []).length;
    if (count === 0) {
      return null;
    }
    return count === 1 ? '1 subcategoría' : `${count} subcategorías`;
  }

  protected countLabel(count: number): string {
    return count === 1 ? '1 movimiento' : `${count} movimientos`;
  }

  protected async create(parentId: string | null = null): Promise<void> {
    const ref = this.dialogs.open<CategoryFormDialog, CategoryFormData, Category>(CategoryFormDialog, {
      data: { kind: this.kind(), parentId },
    });
    if (await firstValueFrom(ref.closed)) {
      this.toast.show('Categoría creada');
    }
  }

  protected async edit(category: Category): Promise<void> {
    const ref = this.dialogs.open<CategoryFormDialog, CategoryFormData, Category>(CategoryFormDialog, {
      data: { kind: category.kind, category },
    });
    if (await firstValueFrom(ref.closed)) {
      this.toast.show('Categoría actualizada');
    }
  }

  protected async setArchived(category: Category, archived: boolean): Promise<void> {
    try {
      await this.categories.update(category.id, { archived });
      this.toast.withUndo(archived ? `${category.name} archivada` : `${category.name} recuperada`, () =>
        this.categories.update(category.id, { archived: !archived }),
      );
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido actualizar la categoría.'));
    }
  }

  protected async remove(category: Category): Promise<void> {
    const entry = this.categories.find(category.id);
    if (!entry) {
      return;
    }
    const ref = this.dialogs.open<DeleteCategoryDialog, DeleteCategoryData, boolean>(DeleteCategoryDialog, {
      data: { entry: { ...entry, category } },
    });
    if (await firstValueFrom(ref.closed)) {
      this.toast.show('Categoría eliminada');
    }
  }

  protected async renameTag(tag: Tag): Promise<void> {
    const ref = this.dialogs.open<RenameTagDialog, TagDialogData, Tag>(RenameTagDialog, { data: { tag } });
    if (await firstValueFrom(ref.closed)) {
      this.toast.show('Etiqueta renombrada');
    }
  }

  protected async mergeTag(tag: Tag): Promise<void> {
    const ref = this.dialogs.open<MergeTagDialog, TagDialogData, Tag>(MergeTagDialog, { data: { tag } });
    const target = await firstValueFrom(ref.closed);
    if (target) {
      this.toast.show(`#${tag.name} fusionada con #${target.name}`);
    }
  }

  protected async deleteTag(tag: Tag): Promise<void> {
    const confirmed = await this.dialogs.confirm({
      title: `¿Eliminar #${tag.name}?`,
      message: 'Se quitará de todos sus movimientos. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    });
    if (!confirmed) {
      return;
    }
    try {
      await this.tags.remove(tag.id);
      this.toast.show('Etiqueta eliminada');
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido eliminar la etiqueta.'));
    }
  }
}
