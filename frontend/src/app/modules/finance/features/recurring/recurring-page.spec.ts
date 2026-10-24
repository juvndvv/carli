import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { RecurringRule } from '@finance/data-access/recurring.models';
import { RecurringPage } from './recurring-page';

const plain = (text: string | null | undefined): string => (text ?? '').replace(/\u00a0/g, ' ');

function rule(overrides: Partial<RecurringRule>): RecurringRule {
  return {
    id: 'netflix',
    name: 'Netflix',
    account_id: 'acc',
    account: { id: 'acc', name: 'Cuenta corriente', type: 'checking' },
    category_id: null,
    category: { id: 'subs', name: 'Suscripciones', parent: null, parent_id: null, icon: 'repeat', color: 'c6', kind: 'expense' },
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

describe('RecurringPage', () => {
  async function setup(rules: RecurringRule[]) {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideRouter([]), provideHttpClient(), provideHttpClientTesting()],
    });
    const fixture = TestBed.createComponent(RecurringPage);
    const http = TestBed.inject(HttpTestingController);
    fixture.detectChanges();
    http.expectOne((req) => req.url === '/api/v1/finance/recurring-rules').flush({
      data: rules,
      meta: {
        active_count: rules.length,
        monthly_total_cents: -86399,
        subscriptions: { count: 2, monthly_cents: -2598, yearly_cents: -31176 },
      },
    });
    http.expectOne('/api/v1/finance/settings').flush({ data: { remind_days_before: 2 } });
    await new Promise((resolve) => setTimeout(resolve));
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement, http };
  }

  const rules = [
    rule({}),
    rule({
      id: 'spotify',
      name: 'Spotify',
      amount_cents: -1199,
      mode: 'auto',
      pending_transaction: { id: 'tx', date: '2026-10-23', amount_cents: -1199 },
    }),
    rule({ id: 'salary', name: 'Nómina Acme S.L.', kind: 'income', amount_cents: 265000, is_subscription: false, category: null }),
    rule({ id: 'gym', name: 'Gimnasio', cancelled: true, active: false }),
  ];

  it('shows subscription totals and the reminder', async () => {
    const { element } = await setup(rules);
    const stats = Array.from(element.querySelectorAll('ui-stat')).map((stat) => plain(stat.textContent));
    expect(stats[0]).toContain('Suscripciones al mes');
    expect(stats[0]).toContain('−25,98 €');
    expect(stats[0]).toContain('2 activas');
    expect(stats[1]).toContain('−311,76 €');
    expect(stats[2]).toContain('2 días antes');
  });

  it('lists active rules with schedule, badges and signed amounts', async () => {
    const { element } = await setup(rules);
    const rows = Array.from(element.querySelectorAll('ui-list-item'));
    expect(rows).toHaveLength(3);
    expect(rows[0].textContent).toContain('Mensual · día 27 · próximo 27 oct');
    expect(rows[0].textContent).toContain('Suscripción');
    expect(plain(rows[0].textContent)).toContain('−13,99 €');
    expect(rows[1].textContent).toContain('Pendiente');
    expect(rows[1].textContent).toContain('Confirmar');
    expect(plain(rows[2].textContent)).toContain('+2.650,00 €');
    expect(rows[2].querySelector('.value')?.classList).toContain('pos');
  });

  it('switches to pending and cancelled tabs', async () => {
    const { element, fixture } = await setup(rules);
    const tabs = Array.from(element.querySelectorAll<HTMLButtonElement>('ui-tabs .tab'));
    expect(tabs[2].textContent).toContain('Pendientes de confirmar');
    expect(tabs[2].textContent).toContain('1');

    tabs[2].click();
    await fixture.whenStable();
    expect(Array.from(element.querySelectorAll('ui-list-item')).map((row) => row.querySelector('.title')?.textContent)).toEqual([
      'Spotify',
    ]);

    tabs[3].click();
    await fixture.whenStable();
    const cancelled = element.querySelectorAll('ui-list-item');
    expect(cancelled).toHaveLength(1);
    expect(cancelled[0].textContent).toContain('Cancelada');
  });

  it('explains the section when there are no rules yet', async () => {
    const { element } = await setup([]);
    expect(element.querySelector('ui-empty-state')?.textContent).toContain('Aún no tienes recurrentes');
  });
});
