import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { apiUrl, firstValidationMessage } from '../http/api';
import { ALL_PENDING, PendingFilter, PendingItem, PendingPageResponse, PendingSummary, samePendingFilter } from './pending.models';

export const PENDING_STALE_MS = 30_000;
const INVALIDATE_DEBOUNCE_MS = 300;

@Injectable({ providedIn: 'root' })
export class PendingStore {
  private readonly http = inject(HttpClient);

  private readonly summaryState = signal<PendingSummary | null>(null);
  private readonly itemsState = signal<PendingItem[]>([]);
  private readonly filterState = signal<PendingFilter>(ALL_PENDING);
  private readonly cursorState = signal<string | null>(null);
  private readonly listLoadingState = signal(false);
  private readonly listLoadedState = signal(false);
  private readonly listErrorState = signal<string | null>(null);

  private summaryRequest: Promise<void> | null = null;
  private summaryFetchedAt = 0;
  private listRequestId = 0;
  private invalidateTimer: ReturnType<typeof setTimeout> | null = null;

  readonly summary = this.summaryState.asReadonly();
  readonly total = computed(() => this.summaryState()?.total ?? 0);
  readonly entries = computed(() => this.summaryState()?.by_module ?? []);
  readonly summaryLoaded = computed(() => this.summaryState() !== null);

  readonly items = this.itemsState.asReadonly();
  readonly filter = this.filterState.asReadonly();
  readonly hasMore = computed(() => this.cursorState() !== null);
  readonly listLoading = this.listLoadingState.asReadonly();
  readonly listLoaded = this.listLoadedState.asReadonly();
  readonly listError = this.listErrorState.asReadonly();

  count(module: string, type?: string): number {
    return this.entries()
      .filter((entry) => entry.module === module && (type === undefined || entry.type === type))
      .reduce((sum, entry) => sum + entry.count, 0);
  }

  refreshSummary(): Promise<void> {
    if (this.summaryRequest) {
      return this.summaryRequest;
    }
    this.summaryRequest = (async () => {
      try {
        const response = await firstValueFrom(this.http.get<{ data: PendingSummary }>(apiUrl('pending/summary')));
        this.summaryState.set(response.data);
        this.summaryFetchedAt = Date.now();
      } catch {
        return;
      } finally {
        this.summaryRequest = null;
      }
    })();
    return this.summaryRequest;
  }

  refreshSummaryIfStale(maxAgeMs = PENDING_STALE_MS): Promise<void> {
    if (this.summaryState() !== null && Date.now() - this.summaryFetchedAt < maxAgeMs) {
      return Promise.resolve();
    }
    return this.refreshSummary();
  }

  invalidate(): void {
    if (this.summaryState() === null) {
      return;
    }
    if (this.invalidateTimer) {
      clearTimeout(this.invalidateTimer);
    }
    this.invalidateTimer = setTimeout(() => {
      this.invalidateTimer = null;
      void this.refreshSummary();
    }, INVALIDATE_DEBOUNCE_MS);
  }

  async load(filter: PendingFilter = ALL_PENDING): Promise<void> {
    const id = ++this.listRequestId;
    if (!samePendingFilter(filter, this.filterState())) {
      this.itemsState.set([]);
      this.listLoadedState.set(false);
    }
    this.filterState.set(filter);
    this.listLoadingState.set(true);
    this.listErrorState.set(null);
    try {
      const [page] = await Promise.all([this.fetchPage(filter, null), this.refreshSummary()]);
      if (id !== this.listRequestId) {
        return;
      }
      this.itemsState.set(page.data);
      this.cursorState.set(page.meta.has_more ? page.meta.next_cursor : null);
      this.listLoadedState.set(true);
    } catch (error) {
      if (id === this.listRequestId) {
        this.listErrorState.set(firstValidationMessage(error, 'Comprueba tu conexión e inténtalo de nuevo.'));
      }
    } finally {
      if (id === this.listRequestId) {
        this.listLoadingState.set(false);
      }
    }
  }

  reloadList(): Promise<void> {
    return this.listLoadedState() ? this.load(this.filterState()) : Promise.resolve();
  }

  async loadMore(): Promise<void> {
    const cursor = this.cursorState();
    if (!cursor || this.listLoadingState()) {
      return;
    }
    const id = this.listRequestId;
    this.listLoadingState.set(true);
    try {
      const page = await this.fetchPage(this.filterState(), cursor);
      if (id !== this.listRequestId) {
        return;
      }
      const known = new Set(this.itemsState().map(itemKey));
      this.itemsState.update((items) => [...items, ...page.data.filter((item) => !known.has(itemKey(item)))]);
      this.cursorState.set(page.meta.has_more ? page.meta.next_cursor : null);
    } catch (error) {
      if (id === this.listRequestId) {
        this.listErrorState.set(firstValidationMessage(error, 'No se han podido cargar más pendientes.'));
      }
    } finally {
      if (id === this.listRequestId) {
        this.listLoadingState.set(false);
      }
    }
  }

  resolve(item: PendingItem): void {
    const key = itemKey(item);
    const before = this.itemsState().length;
    this.itemsState.update((items) => items.filter((current) => itemKey(current) !== key));
    const removed = this.itemsState().length < before;
    this.summaryState.update((summary) => (summary ? decrement(summary, item) : summary));
    if (removed && this.itemsState().length === 0 && this.hasMore()) {
      void this.loadMore();
    }
    this.invalidate();
  }

  private fetchPage(filter: PendingFilter, cursor: string | null): Promise<PendingPageResponse> {
    const params: Record<string, string> = {};
    if (filter.module) {
      params['module'] = filter.module;
    }
    if (filter.type) {
      params['type'] = filter.type;
    }
    if (cursor) {
      params['cursor'] = cursor;
    }
    return firstValueFrom(this.http.get<PendingPageResponse>(apiUrl('pending'), { params }));
  }
}

const itemKey = (item: PendingItem): string => `${item.module}:${item.type}:${item.id}`;

function decrement(summary: PendingSummary, item: PendingItem): PendingSummary {
  const entry = summary.by_module.find((current) => current.module === item.module && current.type === item.type);
  if (!entry || entry.count === 0) {
    return summary;
  }
  return {
    total: Math.max(0, summary.total - 1),
    by_module: summary.by_module
      .map((current) => (current === entry ? { ...current, count: current.count - 1 } : current))
      .filter((current) => current.count > 0),
  };
}
