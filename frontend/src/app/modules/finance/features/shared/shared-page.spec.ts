import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { FinanceContact } from '@finance/data-access/contacts.models';
import { contactSubtitle, SharedPage } from './shared-page';

const plain = (text: string | null | undefined): string => (text ?? '').replace(/\u00a0/g, ' ');

function contact(overrides: Partial<FinanceContact>): FinanceContact {
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

describe('contactSubtitle', () => {
  it('summarises what is pending with each contact', () => {
    expect(plain(contactSubtitle(contact({})))).toBe('40,00 € en gastos sin liquidar');
    expect(plain(contactSubtitle(contact({ shares_pending_cents: 0, owed_to_me_cents: 30000 })))).toBe('Te debe 300,00 € en préstamos');
    expect(plain(contactSubtitle(contact({ shares_pending_cents: 0 })))).toBe('Sin nada pendiente');
  });
});

describe('SharedPage', () => {
  it('shows balances from my point of view and offers settling only with pending shares', async () => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideRouter([]), provideHttpClient(), provideHttpClientTesting()],
    });
    const fixture = TestBed.createComponent(SharedPage);
    const http = TestBed.inject(HttpTestingController);
    fixture.detectChanges();
    http.expectOne('/api/v1/finance/contacts').flush({
      data: [
        contact({}),
        contact({ id: 'carlos', name: 'Carlos', balance_cents: -2350, shares_pending_cents: 0, i_owe_cents: 2350 }),
      ],
      meta: { owed_to_me_cents: 4000, i_owe_cents: 2350 },
    });
    await new Promise((resolve) => setTimeout(resolve));
    await fixture.whenStable();

    const element = fixture.nativeElement as HTMLElement;
    const stats = Array.from(element.querySelectorAll('ui-stat')).map((stat) => plain(stat.textContent));
    expect(stats[0]).toContain('40,00 €');
    expect(stats[0]).toContain('1 persona');
    expect(stats[1]).toContain('23,50 €');

    const rows = Array.from(element.querySelectorAll('.contact-row'));
    expect(plain(rows[0].textContent)).toContain('Te debe 40,00 €');
    expect(rows[0].textContent).toContain('Liquidar');
    expect(plain(rows[1].textContent)).toContain('Le debes 23,50 €');
    expect(rows[1].textContent).not.toContain('Liquidar');
    http.verify();
  });
});
