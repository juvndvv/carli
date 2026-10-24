import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { Category, CategoryInput, CategoryKind } from './finance.models';

export interface CategoryEntry {
  category: Category;
  parent: Category | null;
  icon: string;
  label: string;
}

export const FALLBACK_CATEGORY_ICON = 'circle-dashed';

@Injectable({ providedIn: 'root' })
export class CategoriesService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: Category[] }>(() => {
    this.changes.version('categories')();
    return { url: financeUrl('categories'), params: { include_archived: 1 } };
  });

  readonly tree = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly activeTree = computed(() =>
    this.tree()
      .filter((category) => !category.archived)
      .map((category) => ({ ...category, children: (category.children ?? []).filter((child) => !child.archived) })),
  );
  readonly entries = computed<CategoryEntry[]>(() =>
    this.tree().flatMap((parent) => [
      toEntry(parent, null),
      ...(parent.children ?? []).map((child) => toEntry(child, parent)),
    ]),
  );
  readonly loading = this.resource.isLoading;
  readonly loaded = computed(() => this.resource.hasValue());
  readonly payrollCategories = computed(() => this.entries().filter((entry) => entry.category.opens_period));

  private readonly byId = computed(() => new Map(this.entries().map((entry) => [entry.category.id, entry])));

  find(id: string | null | undefined): CategoryEntry | undefined {
    return id ? this.byId().get(id) : undefined;
  }

  topLevel(kind: CategoryKind): Category[] {
    return this.activeTree().filter((category) => category.kind === kind);
  }

  selectable(kind: CategoryKind): CategoryEntry[] {
    return this.entries().filter((entry) => entry.category.kind === kind && !entry.category.archived && !entry.parent?.archived);
  }

  reload(): void {
    this.resource.reload();
  }

  async create(input: CategoryInput): Promise<Category> {
    const body = await firstValueFrom(this.http.post<{ data: Category }>(financeUrl('categories'), input));
    this.changes.notify('categories');
    return body.data;
  }

  async update(id: string, input: CategoryInput): Promise<Category> {
    const body = await firstValueFrom(this.http.patch<{ data: Category }>(financeUrl(`categories/${id}`), input));
    this.changes.notify('categories');
    return body.data;
  }

  async remove(id: string, reassignTo?: string | null): Promise<void> {
    await firstValueFrom(
      this.http.delete(financeUrl(`categories/${id}`), { params: reassignTo ? { reassign_to: reassignTo } : {} }),
    );
    this.changes.notify('categories', 'transactions', 'budgets');
  }
}

function toEntry(category: Category, parent: Category | null): CategoryEntry {
  return {
    category,
    parent,
    icon: category.icon ?? parent?.icon ?? FALLBACK_CATEGORY_ICON,
    label: parent ? `${parent.name} › ${category.name}` : category.name,
  };
}
