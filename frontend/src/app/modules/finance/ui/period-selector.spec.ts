import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { aPeriod } from '../testing/finance-fixtures';
import { configureFinanceTesting } from '../testing/finance-testing';
import { FinPeriodSelector, periodButtonLabel } from './period-selector';

@Component({
  imports: [FinPeriodSelector],
  template: `<fin-period-selector [periods]="periods" [(value)]="value" />`,
})
class Host {
  readonly periods = [
    aPeriod(),
    aPeriod({ id: 'sep', is_current: false, end_date: '2026-09-27', name: 'Periodo de septiembre', short_name: 'sep', range_label: '28 ago – 27 sep' }),
  ];
  readonly value = signal<string | null>(null);
}

describe('FinPeriodSelector', () => {
  it('labels the open period up to today', () => {
    expect(periodButtonLabel(aPeriod())).toBe('Periodo de octubre · 28 sep – hoy');
  });

  it('moves between periods with the arrows', async () => {
    configureFinanceTesting();
    const fixture = TestBed.createComponent(Host);
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    const [previous, , next] = Array.from(element.querySelectorAll<HTMLButtonElement>('fin-period-selector > button'));
    expect(element.textContent).toContain('Periodo de octubre · 28 sep – hoy');
    expect(next.disabled).toBe(true);
    previous.click();
    await fixture.whenStable();
    expect(fixture.componentInstance.value()).toBe('sep');
    expect(element.textContent).toContain('Periodo de septiembre');
  });
});
