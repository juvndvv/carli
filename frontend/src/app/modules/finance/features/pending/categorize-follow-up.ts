import { InjectionToken } from '@angular/core';
import { PendingItem } from '@core/pending/pending.models';
import { CategoryKind } from '../../data-access/finance.models';

export interface CategorizedPendingTransaction {
  item: PendingItem;
  transactionId: string;
  categoryId: string;
  kind: CategoryKind;
}

export type CategorizeFollowUp = (event: CategorizedPendingTransaction) => Promise<void> | void;

export const CATEGORIZE_FOLLOW_UPS = new InjectionToken<CategorizeFollowUp[]>('CATEGORIZE_FOLLOW_UPS', {
  factory: () => [],
});
