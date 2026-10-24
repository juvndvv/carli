import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { RecurringRule, RecurringRulesMeta } from './recurring.models';
import { RecurringService } from './recurring.service';

const BASE = '/api/v1/finance/recurring-rules';

const META: RecurringRulesMeta = {
  active_count: 2,
  monthly_total_cents: -86399,
  subscriptions: { count: 1, monthly_cents: -1399, yearly_cents: -16788 },
};

function rule(overrides: Partial<RecurringRule> = {}): RecurringRule {
  return {
    id: 'netflix',
    name: 'Netflix',
    account_id: 'acc',
    account: { id: 'acc', name: 'Cuenta corriente', type: 'checking' },
    category_id: null,
    category: null,
    kind: 'expense',
    amount_cents: -1399,
    payee: 'Netflix',
    description: null,
    frequency: 'monthly',
    interval: 1,
    day_of_month: 27,
    start_date: '2026-01-27',
    end_date: null,
    next_occurrence: '2026-10-27',
    mode: 'confirm',
    remind_days_before: 2,
    is_subscription: true,
    cancelled: false,
    cancelled_at: null,
    active: true,
    monthly_cost_cents: -1399,
    yearly_cost_cents: -16788,
    pending_transaction: null,
    debt_id: null,
    created_at: null,
    updated_at: null,
    ...overrides,
  };
}

describe('RecurringService', () => {
  let service: RecurringService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(RecurringService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  async function flushIndex(rules: RecurringRule[]): Promise<void> {
    const request = http.expectOne((req) => req.url === BASE && req.method === 'GET');
    expect(request.request.params.get('include_cancelled')).toBe('1');
    request.flush({ data: rules, meta: META });
    await Promise.resolve();
  }

  it('loads rules including cancelled ones and exposes the pending count', async () => {
    const loading = service.load();
    expect(service.loading()).toBe(true);
    await flushIndex([
      rule(),
      rule({ id: 'light', pending_transaction: { id: 'tx', date: '2026-10-23', amount_cents: -4500 } }),
    ]);
    await loading;

    expect(service.loading()).toBe(false);
    expect(service.loaded()).toBe(true);
    expect(service.rules()).toHaveLength(2);
    expect(service.meta()?.subscriptions.monthly_cents).toBe(-1399);
    expect(service.pendingCount()).toBe(1);
  });

  it('keeps a Spanish error message when loading fails', async () => {
    const loading = service.load();
    http.expectOne((req) => req.url === BASE).flush({ message: 'boom' }, { status: 500, statusText: 'Server error' });
    await loading;
    expect(service.error()).toBe('boom');
    expect(service.loaded()).toBe(false);
  });

  it('confirms a pending occurrence and replaces the rule', async () => {
    service.rules.set([rule()]);
    const confirming = service.confirm('netflix', { amount_cents: 1499, date: '2026-10-27', update_rule_amount: true });

    const request = http.expectOne(`${BASE}/netflix/confirm`);
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ amount_cents: 1499, date: '2026-10-27', update_rule_amount: true });
    request.flush({
      data: {
        transaction: { id: 'tx', amount_cents: -1499, date: '2026-10-27' },
        rule: rule({ amount_cents: -1499 }),
        price_changed: true,
        previous_amount_cents: -1399,
      },
    });

    const result = await confirming;
    expect(result.price_changed).toBe(true);
    expect(service.rules()[0].amount_cents).toBe(-1499);
    await flushIndex([rule({ amount_cents: -1499 })]);
  });

  it('cancels a subscription with a partial update', async () => {
    service.rules.set([rule()]);
    const cancelling = service.setCancelled('netflix', true);
    const request = http.expectOne(`${BASE}/netflix`);
    expect(request.request.method).toBe('PATCH');
    expect(request.request.body).toEqual({ cancelled: true });
    request.flush({ data: rule({ cancelled: true, active: false }) });
    await cancelling;

    expect(service.rules()[0].cancelled).toBe(true);
    expect(service.subscriptions()).toHaveLength(0);
    await flushIndex([rule({ cancelled: true, active: false })]);
  });

  it('removes a rule locally before refreshing totals', async () => {
    service.rules.set([rule(), rule({ id: 'rent' })]);
    const removing = service.remove('rent');
    http.expectOne({ url: `${BASE}/rent`, method: 'DELETE' }).flush(null, { status: 204, statusText: 'No Content' });
    await removing;
    expect(service.rules().map((current) => current.id)).toEqual(['netflix']);
    await flushIndex([rule()]);
  });

  it('reads the reminder days from the finance settings', async () => {
    const loading = service.loadReminderSettings();
    http.expectOne('/api/v1/finance/settings').flush({ data: { remind_days_before: 3 } });
    await loading;
    expect(service.reminderDays()).toBe(3);
  });

  it('fetches only active categories of the requested kind', async () => {
    const loading = service.categories('expense');
    const request = http.expectOne((req) => req.url === '/api/v1/finance/categories');
    expect(request.request.params.get('flat')).toBe('1');
    expect(request.request.params.get('kind')).toBe('expense');
    request.flush({
      data: [
        { id: 'a', name: 'Ocio', kind: 'expense', parent_id: null, icon: 'party-popper', archived: false },
        { id: 'b', name: 'Antigua', kind: 'expense', parent_id: null, icon: null, archived: true },
      ],
    });
    expect((await loading).map((category) => category.id)).toEqual(['a']);
  });
});
