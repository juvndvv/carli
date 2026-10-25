import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiListItem } from '@ui/list-item/list-item';
import { UiSearch } from '@ui/search/search';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ToastService } from '@ui/toast/toast.service';
import { CategoryRule } from '../../data-access/bank.models';
import { FALLBACK_CATEGORY_ICON } from '../../data-access/categories.service';
import { CategoryRulesService } from '../../data-access/category-rules.service';

const SEARCH_THRESHOLD = 8;

export function ruleCategoryLabel(rule: CategoryRule): string {
  const category = rule.category;
  const name = category ? (category.parent ? `${category.parent} › ${category.name}` : category.name) : 'Categoría eliminada';
  return rule.kind === 'income' ? `${name} · ingreso` : name;
}

@Component({
  selector: 'fin-category-rules-card',
  imports: [UiCard, UiListItem, UiButton, UiSearch, UiSkeleton, UiEmptyState],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-card heading="Reglas de categorización">
      <p class="small muted intro">
        Los movimientos importados cuyo comercio o concepto contiene el texto de una regla entran ya categorizados y no pasan por Pendientes.
      </p>
      @if (rules.error() && !rules.loaded()) {
        <ui-empty-state icon="circle-alert" heading="No se han podido cargar las reglas" description="Comprueba tu conexión e inténtalo de nuevo.">
          <button ui-button type="button" size="sm" icon="refresh-cw" (click)="rules.reload()">Reintentar</button>
        </ui-empty-state>
      } @else if (!rules.loaded()) {
        <ui-skeleton height="44px" />
        <ui-skeleton height="44px" class="gap" />
      } @else if (rules.rules().length === 0) {
        <p class="small faint">
          Aún no hay reglas. Al categorizar un movimiento importado te ofreceremos aplicarlo a los parecidos y recordarlo.
        </p>
      } @else {
        @if (rules.rules().length > searchThreshold) {
          <ui-search placeholder="Buscar regla" ariaLabel="Buscar regla" class="search" [value]="query()" (valueChange)="query.set($event)" />
        }
        <div class="ui-list">
          @for (rule of visible(); track rule.id) {
            <ui-list-item [heading]="rule.pattern" [subtitle]="categoryLabel(rule)" [icon]="rule.category?.icon ?? fallbackIcon">
              <button
                trailing
                ui-button
                type="button"
                variant="ghost"
                size="sm"
                icon="trash"
                iconOnly
                [attr.aria-label]="'Eliminar la regla ' + rule.pattern"
                [loading]="removing() === rule.id"
                (click)="remove(rule)"
              ></button>
            </ui-list-item>
          } @empty {
            <p class="small faint">Ninguna regla coincide con «{{ query() }}».</p>
          }
        </div>
      }
    </ui-card>
  `,
  styles: `
    :host {
      display: block;
    }
    .intro {
      margin-top: -6px;
      margin-bottom: 8px;
    }
    .gap {
      margin-top: 8px;
    }
    .search {
      margin-bottom: 8px;
    }
  `,
})
export class CategoryRulesCard {
  protected readonly rules = inject(CategoryRulesService);
  private readonly toast = inject(ToastService);

  protected readonly searchThreshold = SEARCH_THRESHOLD;
  protected readonly fallbackIcon = FALLBACK_CATEGORY_ICON;
  protected readonly query = signal('');
  protected readonly removing = signal<string | null>(null);
  protected readonly visible = computed(() => {
    const query = this.query().trim().toUpperCase();
    return query === ''
      ? this.rules.rules()
      : this.rules.rules().filter((rule) => rule.pattern.toUpperCase().includes(query) || ruleCategoryLabel(rule).toUpperCase().includes(query));
  });

  protected categoryLabel(rule: CategoryRule): string {
    return ruleCategoryLabel(rule);
  }

  protected async remove(rule: CategoryRule): Promise<void> {
    this.removing.set(rule.id);
    try {
      await this.rules.remove(rule.id);
      this.toast.withUndo(`Regla «${rule.pattern}» eliminada`, () => this.restore(rule));
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido eliminar la regla.'));
    } finally {
      this.removing.set(null);
    }
  }

  private async restore(rule: CategoryRule): Promise<void> {
    try {
      await this.rules.create(rule.pattern, rule.category_id);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido recuperar la regla.'));
    }
  }
}
