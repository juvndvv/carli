import { inject, Injectable } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { PendingStore } from '@core/pending/pending.store';
import { ToastService } from '@ui/toast/toast.service';
import { CategoriesService } from '../../data-access/categories.service';
import { TransactionsService } from '../../data-access/transactions.service';

export const SIMILAR_OFFER_DURATION = 10000;

export function similarMessage(count: number): string {
  return count === 1 ? 'Hay 1 movimiento parecido sin categoría' : `Hay ${count} movimientos parecidos sin categoría`;
}

export function applySimilarLabel(count: number): string {
  return count === 1 ? 'Aplicar al parecido y recordar' : `Aplicar a los ${count} parecidos y recordar`;
}

export function appliedMessage(updated: number, pattern: string | null, category: string): string {
  const moved = updated === 1 ? '1 movimiento más' : `${updated} movimientos más`;
  return pattern ? `${moved} en ${category} · regla «${pattern}» guardada` : `${moved} en ${category}`;
}

@Injectable({ providedIn: 'root' })
export class SimilarCategorization {
  private readonly transactions = inject(TransactionsService);
  private readonly categories = inject(CategoriesService);
  private readonly toast = inject(ToastService);
  private readonly pending = inject(PendingStore);

  async offer(transactionId: string, categoryId: string): Promise<boolean> {
    let count: number;
    try {
      count = (await this.transactions.similar(transactionId)).count;
    } catch {
      return false;
    }
    if (count === 0) {
      return false;
    }
    this.toast.enqueue({
      message: similarMessage(count),
      duration: SIMILAR_OFFER_DURATION,
      action: { label: applySimilarLabel(count), handler: () => this.apply(transactionId, categoryId) },
    });
    return true;
  }

  async apply(transactionId: string, categoryId: string): Promise<void> {
    try {
      const result = await this.transactions.categorizeSimilar(transactionId, { category_id: categoryId, remember: true });
      void this.pending.reloadList();
      const category = this.categories.find(categoryId)?.label ?? 'la categoría elegida';
      this.toast.show(appliedMessage(result.updated, result.rule?.pattern ?? null, category));
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se han podido categorizar los parecidos.'));
    }
  }
}
