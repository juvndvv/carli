import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { CategoryRule } from './bank.models';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';

@Injectable({ providedIn: 'root' })
export class CategoryRulesService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: CategoryRule[] }>(() => {
    this.changes.version('rules')();
    this.changes.version('categories')();
    return financeUrl('category-rules');
  });

  readonly rules = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly loaded = computed(() => this.resource.hasValue());
  readonly error = this.resource.error;

  reload(): void {
    this.resource.reload();
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(financeUrl(`category-rules/${id}`)));
    this.changes.notify('rules');
  }

  async create(pattern: string, categoryId: string): Promise<CategoryRule> {
    const body = await firstValueFrom(
      this.http.post<{ data: CategoryRule }>(financeUrl('category-rules'), { pattern, category_id: categoryId }),
    );
    this.changes.notify('rules');
    return body.data;
  }
}
