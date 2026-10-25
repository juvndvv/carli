import { DialogRef } from '@angular/cdk/dialog';
import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { BankRedirect } from '../../data-access/bank.service';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { aspspSubtitle, ConnectBankDialog, matchesAspsp } from './connect-bank-dialog';

const aspsp = (name: string, country = 'ES', consent_days = 90) => ({ name, country, logo: null, consent_days });

describe('ConnectBankDialog', () => {
  let http: HttpTestingController;
  const go = vi.fn<(url: string) => void>();

  async function render() {
    go.mockReset();
    http = configureFinanceTesting(
      [],
      [
        { provide: BankRedirect, useValue: { go } },
        { provide: DialogRef, useValue: { close: vi.fn(), config: { panelClass: [] } } },
      ],
    );
    const fixture = TestBed.createComponent(ConnectBankDialog);
    fixture.detectChanges();
    http.expectOne('/api/v1/finance/bank/aspsps?country=ES').flush({ data: [aspsp('BBVA'), aspsp('MyInvestor')] });
    http.expectOne('/api/v1/finance/bank/aspsps?country=LT').flush({ data: [aspsp('Revolut', 'LT', 180)] });
    await tick();
    flushAll(http, 'bank/connections', { data: [] });
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement };
  }

  it('lists the banks and connects the chosen one', async () => {
    const { element } = await render();
    const buttons = Array.from(element.querySelectorAll<HTMLButtonElement>('.banks button'));
    expect(buttons).toHaveLength(3);
    expect(buttons[2].textContent).toContain('Revolut');
    expect(buttons[2].textContent).toContain('LT · Permiso de 180 días');

    buttons[0].click();
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections' });
    expect(request.request.body).toEqual({ aspsp_name: 'BBVA', aspsp_country: 'ES' });
    request.flush({ data: { auth_url: 'https://bank.example/auth' } });
    await tick();
    expect(go).toHaveBeenCalledWith('https://bank.example/auth');
  });

  it('shows the server message when bank sync is not configured', async () => {
    const { fixture, element } = await render();
    element.querySelector<HTMLButtonElement>('.banks button')!.click();
    http
      .expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections' })
      .flush({ message: 'La sincronización bancaria no está configurada.' }, { status: 503, statusText: 'Unavailable' });
    await tick();
    await fixture.whenStable();
    expect(element.querySelector('[role="alert"]')?.textContent).toContain('no está configurada');
    expect(go).not.toHaveBeenCalled();
    expect(element.querySelectorAll('.banks button')).toHaveLength(3);
  });

  it('filters ignoring accents and case', () => {
    expect(matchesAspsp(aspsp('Caixa Enginyers'), 'ENGINY')).toBe(true);
    expect(matchesAspsp(aspsp('Abanca'), 'bbva')).toBe(false);
    expect(aspspSubtitle(aspsp('BBVA'))).toBe('Permiso de 90 días');
  });
});
