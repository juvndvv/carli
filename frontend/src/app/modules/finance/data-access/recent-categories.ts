import { Injectable, signal } from '@angular/core';
import { CategoryKind } from './finance.models';

const STORAGE_KEY = 'pa-finance-recent-categories';
const LIMIT = 8;

type RecentMap = Record<CategoryKind, string[]>;

function read(): RecentMap {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null') as Partial<RecentMap> | null;
    return {
      expense: Array.isArray(parsed?.expense) ? parsed.expense.filter((id) => typeof id === 'string') : [],
      income: Array.isArray(parsed?.income) ? parsed.income.filter((id) => typeof id === 'string') : [],
    };
  } catch {
    return { expense: [], income: [] };
  }
}

@Injectable({ providedIn: 'root' })
export class RecentCategories {
  private readonly state = signal<RecentMap>(read());

  ids(kind: CategoryKind): string[] {
    return this.state()[kind];
  }

  remember(kind: CategoryKind, id: string): void {
    const next = { ...this.state(), [kind]: [id, ...this.state()[kind].filter((item) => item !== id)].slice(0, LIMIT) };
    this.state.set(next);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    } catch {
      return;
    }
  }
}
