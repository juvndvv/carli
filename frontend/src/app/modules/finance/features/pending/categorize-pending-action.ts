import { ChangeDetectionStrategy, Component, computed, inject, input, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { PendingItem } from '@core/pending/pending.models';
import { PendingStore } from '@core/pending/pending.store';
import { UiButton } from '@ui/button/button';
import { UiCategoryPicker } from '@ui/category-picker/category-picker';
import { ToastService } from '@ui/toast/toast.service';
import { CategoriesService } from '../../data-access/categories.service';
import { CategoryKind } from '../../data-access/finance.models';
import { quickCategoryEntries, toCategoryOption } from '../../data-access/quick-categories';
import { RecentCategories } from '../../data-access/recent-categories';
import { TransactionsService } from '../../data-access/transactions.service';
import { CATEGORIZE_FOLLOW_UPS } from './categorize-follow-up';

const QUICK_COUNT = 8;

export function pendingTransactionId(item: PendingItem): string {
  const id = item.meta['transaction_id'];
  return typeof id === 'string' && id !== '' ? id : item.id;
}

export function pendingCategoryKind(item: PendingItem): CategoryKind {
  return item.meta['kind'] === 'income' ? 'income' : 'expense';
}

@Component({
  selector: 'fin-categorize-pending-action',
  imports: [UiButton, UiCategoryPicker],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (open()) {
      <div class="picker" [class.busy]="saving()">
        <ui-category-picker
          [categories]="options()"
          [value]="chosen()"
          [ariaLabel]="'Categoría para ' + item().title"
          (valueChange)="choose($event)"
        />
        <div class="row between tools">
          <button ui-button type="button" variant="ghost" size="sm" [disabled]="saving()" (click)="open.set(false)">Cancelar</button>
          @if (hasMore()) {
            <button ui-button type="button" variant="ghost" size="sm" [disabled]="saving()" (click)="showAll.set(!showAll())">
              {{ showAll() ? 'Ver menos' : 'Ver todas' }}
            </button>
          }
        </div>
      </div>
    } @else {
      <button ui-button type="button" variant="secondary" size="sm" icon="tag" (click)="open.set(true)">Elegir categoría</button>
    }
  `,
  styles: `
    :host {
      display: block;
    }
    .picker {
      display: flex;
      flex-direction: column;
      gap: 4px;
      padding: 8px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
    }
    .picker.busy {
      opacity: 0.6;
      pointer-events: none;
    }
  `,
})
export class CategorizePendingAction {
  private readonly categories = inject(CategoriesService);
  private readonly recents = inject(RecentCategories);
  private readonly transactions = inject(TransactionsService);
  private readonly pending = inject(PendingStore);
  private readonly toast = inject(ToastService);
  private readonly followUps = inject(CATEGORIZE_FOLLOW_UPS);

  readonly item = input.required<PendingItem>();

  protected readonly open = signal(false);
  protected readonly showAll = signal(false);
  protected readonly saving = signal(false);
  protected readonly chosen = signal<string | null>(null);

  private readonly kind = computed(() => pendingCategoryKind(this.item()));
  private readonly selectable = computed(() => this.categories.selectable(this.kind()));
  protected readonly hasMore = computed(() => this.selectable().length > QUICK_COUNT);
  protected readonly options = computed(() => {
    const entries = this.selectable();
    const visible = this.showAll() || !this.hasMore() ? entries : quickCategoryEntries(entries, this.recents.ids(this.kind()), QUICK_COUNT);
    return visible.map(toCategoryOption);
  });

  protected async choose(categoryId: string | null): Promise<void> {
    if (!categoryId || this.saving()) {
      return;
    }
    const item = this.item();
    const transactionId = pendingTransactionId(item);
    const kind = this.kind();
    this.chosen.set(categoryId);
    this.saving.set(true);
    try {
      await this.transactions.update(transactionId, { category_id: categoryId });
    } catch (error) {
      this.chosen.set(null);
      this.toast.error(firstValidationMessage(error, 'No se ha podido guardar la categoría.'));
      return;
    } finally {
      this.saving.set(false);
    }
    this.recents.remember(kind, categoryId);
    this.pending.resolve(item);
    const name = this.categories.find(categoryId)?.label ?? 'la categoría elegida';
    const message = `${item.title} → ${name}`;
    if (item.meta['source'] === 'bank') {
      this.toast.withUndo(message, () => this.undo(transactionId));
    } else {
      this.toast.show(message);
    }
    for (const followUp of this.followUps) {
      await followUp({ item, transactionId, categoryId, kind });
    }
  }

  private async undo(transactionId: string): Promise<void> {
    try {
      await this.transactions.update(transactionId, { category_id: null });
      await this.pending.load(this.pending.filter());
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido deshacer.'));
    }
  }
}
