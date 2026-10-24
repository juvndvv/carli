import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { formatMoney } from '@shared/money/money';
import { Debt, debtInstallmentsLabel } from './debts.models';
import { DebtsService } from './debts.service';

const BASE = '/api/v1/finance/debts';
const plain = (text: string | null | undefined): string => (text ?? '').replace(/\u00a0/g, ' ');

function debt(overrides: Partial<Debt> = {}): Debt {
  return {
    id: 'car',
    name: 'Préstamo coche',
    direction: 'i_owe',
    contact_id: 'cetelem',
    contact: { id: 'cetelem', name: 'Cetelem' },
    principal_cents: 1200000,
    paid_cents: 465000,
    pending_cents: 735000,
    progress_bp: 3875,
    start_date: '2024-05-05',
    due_date: null,
    installment_cents: 24500,
    installments_count: 48,
    installments_paid: 30,
    recurring_rule_id: 'rule',
    next_payment_date: '2026-11-05',
    notes: null,
    closed: false,
    closed_at: null,
    created_at: null,
    updated_at: null,
    ...overrides,
  };
}

describe('debts models', () => {
  it('describes the installment plan', () => {
    expect(plain(debtInstallmentsLabel(debt(), (cents) => formatMoney(cents)))).toBe('245,00 € / mes · 30 de 48 cuotas');
    expect(debtInstallmentsLabel(debt({ installment_cents: null, installments_count: null }), (cents) => formatMoney(cents))).toBe(
      'Sin plan de pagos',
    );
  });
});

describe('DebtsService', () => {
  let service: DebtsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(DebtsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  async function flushIndex(debts: Debt[]): Promise<void> {
    const request = http.expectOne((req) => req.url === BASE && req.method === 'GET');
    expect(request.request.params.get('include_closed')).toBe('1');
    request.flush({ data: debts, meta: { owed_to_me_cents: 30000, i_owe_cents: 735000 } });
    await Promise.resolve();
  }

  it('splits open debts by direction and keeps closed ones apart', async () => {
    const loading = service.load();
    await flushIndex([
      debt(),
      debt({ id: 'luis', direction: 'owed_to_me', contact: { id: 'luis', name: 'Luis' } }),
      debt({ id: 'old', closed: true }),
    ]);
    await loading;
    expect(service.iOwe().map((item) => item.id)).toEqual(['car']);
    expect(service.owedToMe().map((item) => item.id)).toEqual(['luis']);
    expect(service.closedDebts().map((item) => item.id)).toEqual(['old']);
    expect(service.meta().i_owe_cents).toBe(735000);
  });

  it('creates a loan with an installment plan', async () => {
    const creating = service.create({
      name: 'Préstamo coche',
      direction: 'i_owe',
      principal_cents: 1200000,
      start_date: '2026-10-24',
      contact_id: null,
      due_date: null,
      notes: null,
      plan: { account_id: 'acc', installment_cents: 24500, installments_count: 48, first_payment_date: '2026-11-05' },
    });
    const request = http.expectOne({ url: BASE, method: 'POST' });
    expect(request.request.body.plan.installments_count).toBe(48);
    request.flush({ data: debt() });
    await Promise.resolve();
    await flushIndex([debt()]);
    expect((await creating).id).toBe('car');
  });

  it('registers a partial payment and updates the pending balance', async () => {
    service.debts.set([debt()]);
    const paying = service.addPayment('car', { account_id: 'acc', amount_cents: 24500, date: '2026-10-24' });
    const request = http.expectOne(`${BASE}/car/payments`);
    expect(request.request.method).toBe('POST');
    request.flush({
      data: { id: 'tx', account_id: 'acc', account: { id: 'acc', name: 'Cuenta', type: 'checking' }, kind: 'expense', amount_cents: -24500, date: '2026-10-24', category: null, payee: 'Cetelem', description: null, status: 'cleared' },
      meta: { debt: debt({ pending_cents: 710500, installments_paid: 31 }) },
    });
    const result = await paying;
    expect(result.debt.pending_cents).toBe(710500);
    expect(service.debts()[0].installments_paid).toBe(31);
    await flushIndex([debt({ pending_cents: 710500 })]);
  });

  it('undoes a deleted payment by restoring its transaction', async () => {
    const restoring = service.restorePayment('tx');
    const request = http.expectOne('/api/v1/finance/transactions/tx/restore');
    expect(request.request.method).toBe('POST');
    request.flush({ data: {} });
    await restoring;
    await flushIndex([debt()]);
  });
});
