import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { Tag } from './finance.models';

export const normalizeTagName = (raw: string): string => raw.trim().replace(/^#+/, '').trim().toLowerCase();

@Injectable({ providedIn: 'root' })
export class TagsService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: Tag[] }>(() => {
    this.changes.version('tags')();
    return financeUrl('tags');
  });

  readonly all = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly names = computed(() => this.all().map((tag) => tag.name));
  readonly loading = this.resource.isLoading;
  readonly loaded = computed(() => this.resource.hasValue());

  reload(): void {
    this.resource.reload();
  }

  async create(name: string): Promise<Tag> {
    const body = await firstValueFrom(this.http.post<{ data: Tag }>(financeUrl('tags'), { name: normalizeTagName(name) }));
    this.changes.notify('tags');
    return body.data;
  }

  async rename(id: string, name: string): Promise<Tag> {
    const body = await firstValueFrom(
      this.http.patch<{ data: Tag }>(financeUrl(`tags/${id}`), { name: normalizeTagName(name) }),
    );
    this.changes.notify('tags', 'transactions');
    return body.data;
  }

  async merge(id: string, intoTagId: string): Promise<Tag> {
    const body = await firstValueFrom(
      this.http.post<{ data: Tag }>(financeUrl(`tags/${id}/merge`), { into_tag_id: intoTagId }),
    );
    this.changes.notify('tags', 'transactions');
    return body.data;
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(financeUrl(`tags/${id}`)));
    this.changes.notify('tags', 'transactions');
  }
}
