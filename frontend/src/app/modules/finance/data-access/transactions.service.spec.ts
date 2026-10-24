import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { aTransaction, emptyTotals } from '../testing/finance-fixtures';
import { configureFinanceTesting } from '../testing/finance-testing';
import { FinanceChanges } from './finance-changes';
import { duplicateInput, TransactionsService } from './transactions.service';

describe('TransactionsService', () => {
  let http: HttpTestingController;
  let service: TransactionsService;

  beforeEach(() => {
    http = configureFinanceTesting();
    service = TestBed.inject(TransactionsService);
  });

  afterEach(() => http.verify());

  it('sends filters as array params with a cursor', async () => {
    const promise = service.list({ period_id: 'p1', account_id: ['a', 'b'], q: null, min: 0 }, 'cursor-1', 50);
    const request = http.expectOne((req) => req.url === '/api/v1/finance/transactions');
    expect(request.request.params.get('period_id')).toBe('p1');
    expect(request.request.params.getAll('account_id[]')).toEqual(['a', 'b']);
    expect(request.request.params.has('q')).toBe(false);
    expect(request.request.params.get('min')).toBe('0');
    expect(request.request.params.get('cursor')).toBe('cursor-1');
    expect(request.request.params.get('per_page')).toBe('50');
    request.flush({ data: [aTransaction()], meta: { per_page: 50, has_more: false, next_cursor: null, totals: emptyTotals } });
    expect((await promise).data).toHaveLength(1);
  });

  it('notifies dependants after creating a movement', async () => {
    const changes = TestBed.inject(FinanceChanges);
    const before = changes.version('accounts')();
    const promise = service.create({ account_id: 'a', kind: 'expense', amount_cents: -100, date: '2026-10-24' });
    const request = http.expectOne('/api/v1/finance/transactions');
    expect(request.request.method).toBe('POST');
    request.flush({ data: aTransaction(), meta: { periods_changed: true } });
    const result = await promise;
    expect(result.periodsChanged).toBe(true);
    expect(changes.version('accounts')()).toBe(before + 1);
    expect(changes.version('transactions')()).toBe(before + 1);
  });

  it('deletes and restores for undo', async () => {
    const removal = service.remove('tx-1');
    http.expectOne({ method: 'DELETE', url: '/api/v1/finance/transactions/tx-1' }).flush({ meta: { periods_changed: false } });
    expect(await removal).toBe(false);
    const restore = service.restore('tx-1');
    http.expectOne({ method: 'POST', url: '/api/v1/finance/transactions/tx-1/restore' }).flush({ data: aTransaction(), meta: { periods_changed: false } });
    expect((await restore).transaction.id).toBe('tx-1');
  });

  it('builds the CSV export URL with the current filters', () => {
    expect(service.exportUrl({ period_id: 'p1', tag: ['casa'], q: null })).toBe(
      '/api/v1/finance/transactions/export.csv?period_id=p1&tag%5B%5D=casa',
    );
  });

  it('prepares a duplicate keeping splits and shares', () => {
    const source = aTransaction({
      category_id: null,
      splits: [{ id: 's', category_id: 'c', category: aTransaction().category!, amount_cents: -4250 }],
      shares: [
        { id: 'sh', contact_id: 'ana', name: 'Ana', amount_cents: 2000, settled: true, settled_at: null, settlement_transaction_id: null },
      ],
      tags: ['casa'],
    });
    expect(duplicateInput(source, '2026-10-25')).toMatchObject({
      date: '2026-10-25',
      category_id: null,
      splits: [{ category_id: 'c', amount_cents: -4250 }],
      shares: { mode: 'amount', items: [{ contact_id: 'ana', amount_cents: 2000 }] },
      tags: ['casa'],
    });
  });
});
