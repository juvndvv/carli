import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { aPeriod, aTransaction, anAccount } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { groupByDay, TransactionsPage } from './transactions-page';

const page = (data: unknown[], totals = { count: data.length, income_cents: 4500, expense_cents: -10250, own_expense_cents: -10250, net_cents: 0 }) => ({
  data,
  meta: { per_page: 50, has_more: false, next_cursor: null, totals },
});

describe('groupByDay', () => {
  it('groups by date, sums non-transfer amounts and hides the incoming transfer leg', () => {
    const groups = groupByDay(
      [
        aTransaction({ id: 'a', date: '2026-10-24', amount_cents: -4250 }),
        aTransaction({ id: 'b', date: '2026-10-24', amount_cents: 4500, kind: 'income' }),
        aTransaction({ id: 'c', date: '2026-10-23', kind: 'transfer', amount_cents: -50000, transfer_group_id: 'g' }),
        aTransaction({ id: 'd', date: '2026-10-23', kind: 'transfer', amount_cents: 50000, transfer_group_id: 'g' }),
      ],
      true,
    );
    expect(groups.map((group) => [group.date, group.total, group.items.map((item) => item.id)])).toEqual([
      ['2026-10-24', 250, ['a', 'b']],
      ['2026-10-23', 0, ['c']],
    ]);
  });
});

describe('TransactionsPage', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    http = configureFinanceTesting([{ path: 'finanzas/movimientos', component: TransactionsPage }]);
  });

  async function render(url = '/finanzas/movimientos') {
    const harness = await RouterTestingHarness.create();
    await harness.navigateByUrl(url);
    TestBed.tick();
    flushAll(http, 'periods', { data: [aPeriod()] });
    flushAll(http, 'accounts', { data: [anAccount()], meta: { net_worth_cents: 0 } });
    flushAll(http, 'categories', { data: [] });
    flushAll(http, 'tags', { data: [] });
    await tick();
    TestBed.tick();
    return harness;
  }

  it('loads the current period and renders day groups with totals', async () => {
    const harness = await render();
    const requests = http.match((req) => req.url === '/api/v1/finance/transactions');
    const main = requests.find((req) => req.request.params.get('per_page') === '50')!;
    const pendingCount = requests.find((req) => req.request.params.get('status') === 'pending')!;
    expect(main.request.params.get('period_id')).toBe('period-current');
    main.flush(page([aTransaction(), aTransaction({ id: 'tx-2', payee: 'Venta Wallapop', kind: 'income', amount_cents: 4500 })]));
    pendingCount.flush(page([], { count: 1, income_cents: 0, expense_cents: 0, own_expense_cents: 0, net_cents: 0 }));
    await tick();
    harness.detectChanges();
    const text = (harness.routeNativeElement as HTMLElement).textContent!;
    expect(text).toContain('2 movimientos');
    expect(text).toContain('Mercadona');
    expect(text).toContain('Venta Wallapop');
    expect(text).toContain('Pendientes (1)');
    expect(harness.routeNativeElement!.querySelectorAll('fin-transaction-row')).toHaveLength(2);
  });

  it('syncs filter changes to the URL', async () => {
    const harness = await render();
    http.match((req) => req.url === '/api/v1/finance/transactions').forEach((req) => req.flush(page([])));
    await tick();
    harness.detectChanges();
    const pendingChip = Array.from(harness.routeNativeElement!.querySelectorAll<HTMLButtonElement>('button')).find((button) =>
      button.textContent!.includes('Pendientes'),
    )!;
    pendingChip.click();
    await tick();
    expect(TestBed.inject(Router).url).toBe('/finanzas/movimientos?estado=pendiente');
    TestBed.tick();
    const reload = http.match((req) => req.url === '/api/v1/finance/transactions' && req.params.get('per_page') === '50');
    expect(reload.at(-1)!.request.params.get('status')).toBe('pending');
  });

  it('shows the empty state with a first action', async () => {
    const harness = await render();
    http.match((req) => req.url === '/api/v1/finance/transactions').forEach((req) => req.flush(page([], { count: 0, income_cents: 0, expense_cents: 0, own_expense_cents: 0, net_cents: 0 })));
    await tick();
    harness.detectChanges();
    expect(harness.routeNativeElement!.textContent).toContain('Aún no hay movimientos');
  });
});
