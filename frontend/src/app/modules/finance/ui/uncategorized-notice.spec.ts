import { TestBed } from '@angular/core/testing';
import { configureFinanceTesting } from '../testing/finance-testing';
import { FinUncategorizedNotice, uncategorizedMessage } from './uncategorized-notice';

const plain = (text: string | null | undefined): string => (text ?? '').replace(/\u00a0/g, ' ');

describe('uncategorizedMessage', () => {
  it('stays silent without uncategorized spending', () => {
    expect(uncategorizedMessage(null)).toBeNull();
    expect(uncategorizedMessage({ expense_cents: 0, count: 0 })).toBeNull();
  });

  it('describes the amount and how many expenses are left out', () => {
    const message = uncategorizedMessage({ expense_cents: 12345, count: 3 });
    expect(plain(message?.amount)).toBe('123,45 € sin categorizar');
    expect(message?.detail).toBe('3 gastos aún no cuentan en ningún presupuesto.');
    expect(uncategorizedMessage({ expense_cents: 500, count: 1 })?.detail).toBe('1 gasto aún no cuenta en ningún presupuesto.');
  });
});

describe('FinUncategorizedNotice', () => {
  beforeEach(() => configureFinanceTesting());

  it('links to the uncategorized movements of the shown period', async () => {
    const fixture = TestBed.createComponent(FinUncategorizedNotice);
    fixture.componentRef.setInput('summary', { expense_cents: 12345, count: 3 });
    fixture.componentRef.setInput('periodId', 'period-sep');
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;

    expect(plain(element.querySelector('strong')?.textContent)).toBe('123,45 € sin categorizar');
    expect(element.querySelector('a')?.getAttribute('href')).toBe('/finanzas/movimientos?sin_categoria=1&periodo=period-sep');
  });

  it('renders nothing when the amount is zero', async () => {
    const fixture = TestBed.createComponent(FinUncategorizedNotice);
    fixture.componentRef.setInput('summary', { expense_cents: 0, count: 0 });
    await fixture.whenStable();
    expect((fixture.nativeElement as HTMLElement).querySelector('.notice')).toBeNull();
  });
});
