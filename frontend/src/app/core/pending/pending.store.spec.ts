import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { aPendingItem, aSummary } from './testing/pending-fixtures';
import { PendingStore } from './pending.store';

describe('PendingStore', () => {
  let store: PendingStore;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    store = TestBed.inject(PendingStore);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    vi.useRealTimers();
    http.verify();
  });

  it('loads the summary once while a request is in flight', async () => {
    const first = store.refreshSummary();
    const second = store.refreshSummary();
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
    await Promise.all([first, second]);

    expect(store.total()).toBe(3);
    expect(store.count('finance')).toBe(3);
    expect(store.count('finance', 'recurring_to_confirm')).toBe(1);
  });

  it('skips a summary refresh while the last one is fresh', async () => {
    const refresh = store.refreshSummary();
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
    await refresh;

    await store.refreshSummaryIfStale();
    http.expectNone('/api/v1/pending/summary');
  });

  it('keeps the previous summary when the request fails', async () => {
    const refresh = store.refreshSummary();
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
    await refresh;

    const failed = store.refreshSummary();
    http.expectOne('/api/v1/pending/summary').flush(null, { status: 500, statusText: 'Error' });
    await failed;
    expect(store.total()).toBe(3);
  });

  it('loads a filtered page and follows the cursor', async () => {
    const load = store.load({ module: 'finance', type: 'uncategorized_transaction' });
    const first = http.expectOne((request) => request.url === '/api/v1/pending');
    expect(first.request.params.get('module')).toBe('finance');
    expect(first.request.params.get('type')).toBe('uncategorized_transaction');
    expect(first.request.params.has('cursor')).toBe(false);
    first.flush({ data: [aPendingItem()], meta: { has_more: true, next_cursor: 'c1' } });
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
    await load;

    expect(store.listLoaded()).toBe(true);
    expect(store.hasMore()).toBe(true);

    const more = store.loadMore();
    const next = http.expectOne((request) => request.url === '/api/v1/pending');
    expect(next.request.params.get('cursor')).toBe('c1');
    next.flush({ data: [aPendingItem(), aPendingItem({ id: 'tx-2' })], meta: { has_more: false, next_cursor: null } });
    await more;

    expect(store.items().map((item) => item.id)).toEqual(['tx-1', 'tx-2']);
    expect(store.hasMore()).toBe(false);
  });

  it('removes a resolved item and decrements its count right away', async () => {
    const load = store.load();
    http
      .expectOne((request) => request.url === '/api/v1/pending')
      .flush({ data: [aPendingItem(), aPendingItem({ id: 'tx-2' })], meta: { has_more: false, next_cursor: null } });
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary(1, 1) });
    await load;

    vi.useFakeTimers();
    store.resolve(aPendingItem());

    expect(store.items().map((item) => item.id)).toEqual(['tx-2']);
    expect(store.total()).toBe(1);
    expect(store.entries().map((entry) => entry.type)).toEqual(['recurring_to_confirm']);

    vi.advanceTimersByTime(400);
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary(0, 1) });
  });

  it('only refreshes on invalidation after the summary has been loaded', async () => {
    vi.useFakeTimers();
    store.invalidate();
    vi.advanceTimersByTime(400);
    http.expectNone('/api/v1/pending/summary');

    const refresh = store.refreshSummary();
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
    await refresh;

    store.invalidate();
    store.invalidate();
    vi.advanceTimersByTime(400);
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
  });

  it('exposes the error when the list cannot be loaded', async () => {
    const load = store.load();
    http.expectOne((request) => request.url === '/api/v1/pending').flush(null, { status: 500, statusText: 'Error' });
    http.expectOne('/api/v1/pending/summary').flush({ data: aSummary() });
    await load;

    expect(store.listError()).toBe('Comprueba tu conexión e inténtalo de nuevo.');
    expect(store.listLoading()).toBe(false);
  });
});
