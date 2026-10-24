import { TestBed } from '@angular/core/testing';
import { ToastService } from '@ui/toast/toast.service';
import { aCategory, anAccount, aPeriod, someSettings } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { FinanceSettingsPanel } from './finance-settings-panel';

describe('FinanceSettingsPanel', () => {
  it('saves the general settings and toggles payroll categories', async () => {
    const http = configureFinanceTesting();
    const fixture = TestBed.createComponent(FinanceSettingsPanel);
    TestBed.tick();
    flushAll(http, 'settings', { data: someSettings() });
    flushAll(http, 'accounts', { data: [anAccount()], meta: { net_worth_cents: 0 } });
    flushAll(http, 'categories', {
      data: [aCategory({ id: 'payroll', name: 'Nómina', kind: 'income', opens_period: true }), aCategory({ id: 'extra', name: 'Extra', kind: 'income' })],
    });
    flushAll(http, 'periods', { data: [aPeriod()] });
    await tick();
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    expect(element.textContent).toContain('Periodo de octubre');
    expect(element.textContent).toContain('quedan 3 días');

    const threshold = element.querySelector<HTMLInputElement>('#fin-settings-threshold')!;
    expect(threshold.value).toBe('80');
    threshold.value = '90';
    threshold.dispatchEvent(new Event('input'));
    element.querySelector<HTMLFormElement>('form')!.dispatchEvent(new Event('submit'));
    const save = http.expectOne({ method: 'PATCH', url: '/api/v1/finance/settings' });
    expect(save.request.body).toMatchObject({ budget_warning_threshold: 90, period_mode: 'payroll', period_min_days: 20 });
    save.flush({ data: someSettings({ budget_warning_threshold: 90 }), meta: { periods_changed: false } });
    await tick();
    expect(TestBed.inject(ToastService).active()[0].message).toBe('Ajustes guardados');

    const extraSwitch = element.querySelector<HTMLButtonElement>('button[aria-label="Abre periodo: Extra"]')!;
    extraSwitch.click();
    const update = http.expectOne({ method: 'PATCH', url: '/api/v1/finance/categories/extra' });
    expect(update.request.body).toEqual({ opens_period: true });
    update.flush({ data: aCategory({ id: 'extra', kind: 'income', opens_period: true }) });
    await tick();
  });
});
