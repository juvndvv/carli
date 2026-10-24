import { computed, Injectable, Signal, signal } from '@angular/core';

export type FinanceChangeScope =
  | 'transactions'
  | 'accounts'
  | 'categories'
  | 'tags'
  | 'budgets'
  | 'periods'
  | 'settings'
  | 'contacts';

export const TRANSACTION_SIDE_EFFECTS: FinanceChangeScope[] = ['transactions', 'accounts', 'periods', 'budgets', 'tags', 'contacts'];

@Injectable({ providedIn: 'root' })
export class FinanceChanges {
  private readonly counters = signal<Partial<Record<FinanceChangeScope, number>>>({});
  private readonly total = signal(0);
  private readonly cache = new Map<FinanceChangeScope, Signal<number>>();

  readonly any = this.total.asReadonly();

  version(scope: FinanceChangeScope): Signal<number> {
    let tracked = this.cache.get(scope);
    if (!tracked) {
      tracked = computed(() => this.counters()[scope] ?? 0);
      this.cache.set(scope, tracked);
    }
    return tracked;
  }

  notify(...scopes: FinanceChangeScope[]): void {
    this.counters.update((current) => {
      const next = { ...current };
      for (const scope of new Set(scopes)) {
        next[scope] = (next[scope] ?? 0) + 1;
      }
      return next;
    });
    this.total.update((value) => value + 1);
  }

  notifyTransactions(): void {
    this.notify(...TRANSACTION_SIDE_EFFECTS);
  }
}
