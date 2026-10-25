import { inject, InjectionToken } from '@angular/core';
import { PendingItem } from '@core/pending/pending.models';
import { CategoryKind } from '../../data-access/finance.models';
import { SimilarCategorization } from '../rules/similar-categorization';

export interface CategorizedPendingTransaction {
  item: PendingItem;
  transactionId: string;
  categoryId: string;
  kind: CategoryKind;
}

export type CategorizeFollowUp = (event: CategorizedPendingTransaction) => Promise<unknown> | void;

export const CATEGORIZE_FOLLOW_UPS = new InjectionToken<CategorizeFollowUp[]>('CATEGORIZE_FOLLOW_UPS', {
  factory: () => {
    const similar = inject(SimilarCategorization);
    return [({ transactionId, categoryId }) => similar.offer(transactionId, categoryId)];
  },
});
