import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { formatMoney } from '@shared/money/money';
import { contactBalanceLabel, contactBalanceTone, FinanceContact, shareTitle } from './contacts.models';
import { ContactsService } from './contacts.service';

const BASE = '/api/v1/finance/contacts';
const plain = (text: string | null | undefined): string => (text ?? '').replace(/\u00a0/g, ' ');

function contact(overrides: Partial<FinanceContact> = {}): FinanceContact {
  return {
    id: 'ana',
    name: 'Ana',
    notes: null,
    archived: false,
    balance_cents: 4000,
    shares_pending_cents: 4000,
    owed_to_me_cents: 0,
    i_owe_cents: 0,
    ...overrides,
  };
}

describe('contacts models', () => {
  const money = (cents: number) => formatMoney(cents);

  it('phrases balances from my point of view', () => {
    expect(plain(contactBalanceLabel(4000, money))).toBe('Te debe 40,00 €');
    expect(plain(contactBalanceLabel(-2350, money))).toBe('Le debes 23,50 €');
    expect(plain(contactBalanceLabel(0, money))).toBe('En paz');
    expect(contactBalanceTone(4000)).toBe('positive');
    expect(contactBalanceTone(-1)).toBe('default');
    expect(contactBalanceTone(0)).toBe('muted');
  });

  it('titles shares by payee, then description', () => {
    expect(shareTitle({ payee: 'Cena con Ana', description: null })).toBe('Cena con Ana');
    expect(shareTitle({ payee: null, description: 'Luz y agua' })).toBe('Luz y agua');
    expect(shareTitle({ payee: null, description: null })).toBe('Gasto compartido');
  });
});

describe('ContactsService', () => {
  let service: ContactsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(ContactsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  async function flushIndex(contacts: FinanceContact[]): Promise<void> {
    http.expectOne({ url: BASE, method: 'GET' }).flush({
      data: contacts,
      meta: { owed_to_me_cents: 10780, i_owe_cents: 2350 },
    });
    await Promise.resolve();
  }

  it('loads contacts and groups them by who owes whom', async () => {
    const loading = service.load();
    await flushIndex([contact(), contact({ id: 'carlos', name: 'Carlos', balance_cents: -2350 })]);
    await loading;
    expect(service.owingMe().map((item) => item.id)).toEqual(['ana']);
    expect(service.owedByMe().map((item) => item.id)).toEqual(['carlos']);
    expect(service.meta().owed_to_me_cents).toBe(10780);
  });

  it('creates contacts keeping alphabetical order', async () => {
    service.contacts.set([contact({ id: 'carlos', name: 'Carlos' })]);
    const creating = service.create({ name: 'Ana', notes: null });
    http.expectOne({ url: BASE, method: 'POST' }).flush({ data: { ...contact(), shares: [], debts: [] } });
    await creating;
    expect(service.contacts().map((item) => item.name)).toEqual(['Ana', 'Carlos']);
  });

  it('settles a contact into an account and can undo it', async () => {
    const settling = service.settle('ana', { account_id: 'acc', date: '2026-10-24' });
    const request = http.expectOne(`${BASE}/ana/settle`);
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ account_id: 'acc', date: '2026-10-24' });
    request.flush({
      data: {
        transaction: { id: 'tx', amount_cents: 4000, date: '2026-10-24' },
        transactions: [{ id: 'tx', amount_cents: 4000, date: '2026-10-24' }],
        net_cents: 4000,
        contact: contact({ balance_cents: 0, shares_pending_cents: 0 }),
      },
    });
    expect((await settling).transaction.amount_cents).toBe(4000);
    await flushIndex([contact({ balance_cents: 0, shares_pending_cents: 0 })]);

    const undoing = service.undoSettlement('tx');
    http.expectOne({ url: '/api/v1/finance/transactions/tx', method: 'DELETE' }).flush({ meta: {} });
    await undoing;
    await flushIndex([contact()]);
  });
});
