import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { RecurringRule } from '@finance/data-access/recurring.models';
import { ConfirmOccurrenceDialog, detectPriceChange } from './confirm-occurrence-dialog';

const plain = (text: string | null | undefined): string => (text ?? '').replace(/\u00a0/g, ' ');

const RULE: RecurringRule = {
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
  next_occurrence: '2026-11-27',
  mode: 'confirm',
  remind_days_before: 2,
  is_subscription: true,
  cancelled: false,
  cancelled_at: null,
  active: true,
  monthly_cost_cents: -1399,
  yearly_cost_cents: -16788,
  pending_transaction: { id: 'tx', date: '2026-10-27', amount_cents: -1399 },
  debt_id: null,
  created_at: null,
  updated_at: null,
};

describe('detectPriceChange', () => {
  it('ignores equal amounts and empty input', () => {
    expect(detectPriceChange(-1399, 1399)).toBeNull();
    expect(detectPriceChange(-1399, null)).toBeNull();
  });

  it('reports increases and decreases against the absolute expected amount', () => {
    expect(detectPriceChange(-1399, 1499)).toEqual({ direction: 'up', differenceCents: 100, percent: 7 });
    expect(detectPriceChange(-1399, 1199)).toEqual({ direction: 'down', differenceCents: 200, percent: 14 });
  });
});

describe('ConfirmOccurrenceDialog', () => {
  const close = vi.fn();

  async function setup() {
    close.mockReset();
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: DIALOG_DATA, useValue: { rule: RULE } },
        { provide: DialogRef, useValue: { close, config: {} } },
      ],
    });
    const fixture = TestBed.createComponent(ConfirmOccurrenceDialog);
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    const input = element.querySelector('ui-money-input input') as HTMLInputElement;
    const type = async (text: string) => {
      input.value = text;
      input.dispatchEvent(new Event('input'));
      await fixture.whenStable();
    };
    return { fixture, element, input, type, http: TestBed.inject(HttpTestingController) };
  }

  it('prefills the pending amount and shows no warning', async () => {
    const { element, input } = await setup();
    expect(input.value).toBe('13,99');
    expect(element.textContent).toContain('Confirmar Netflix');
    expect(element.querySelector('.notice')).toBeNull();
  });

  it('warns about a price increase when the amount changes', async () => {
    const { element, type } = await setup();
    await type('14,99');
    const notice = element.querySelector('.notice');
    expect(plain(notice?.textContent)).toContain('Sube 1,00 € (7 %) respecto a lo previsto');
    expect(notice?.textContent).toContain('Usar este importe en los próximos cargos');
  });

  it('confirms with the edited amount and updates the rule price', async () => {
    const { element, type, http } = await setup();
    await type('14,99');
    (element.querySelector('form') as HTMLFormElement).dispatchEvent(new Event('submit'));

    const request = http.expectOne('/api/v1/finance/recurring-rules/netflix/confirm');
    expect(request.request.body).toEqual({ amount_cents: 1499, date: '2026-10-27', update_rule_amount: true });
    request.flush({
      data: {
        transaction: { id: 'tx', amount_cents: -1499, date: '2026-10-27' },
        rule: { ...RULE, amount_cents: -1499, pending_transaction: null },
        price_changed: true,
        previous_amount_cents: -1399,
      },
    });
    await vi.waitFor(() => expect(close).toHaveBeenCalled());
    http.expectOne((req) => req.url === '/api/v1/finance/recurring-rules').flush({ data: [], meta: null });
    http.verify();
  });
});
