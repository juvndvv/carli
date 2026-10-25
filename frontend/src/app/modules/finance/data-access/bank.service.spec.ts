import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { configureFinanceTesting, tick } from '../testing/finance-testing';
import { Aspsp } from './bank.models';
import { BankService, mergeAspsps } from './bank.service';
import { FinanceChanges } from './finance-changes';

const aspsp = (name: string, country = 'ES'): Aspsp => ({ name, country, logo: null, consent_days: 90 });

describe('BankService', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    http = configureFinanceTesting();
  });

  it('lists Spanish banks plus Revolut from Lithuania', async () => {
    const result = TestBed.inject(BankService).aspsps();
    http.expectOne('/api/v1/finance/bank/aspsps?country=ES').flush({ data: [aspsp('MyInvestor'), aspsp('BBVA')] });
    http
      .expectOne('/api/v1/finance/bank/aspsps?country=LT')
      .flush({ data: [aspsp('Revolut', 'LT'), aspsp('Swedbank', 'LT')] });
    expect((await result).map((item) => item.name)).toEqual(['BBVA', 'MyInvestor', 'Revolut']);
  });

  it('still lists Spanish banks when the extra country fails', async () => {
    const result = TestBed.inject(BankService).aspsps();
    http.expectOne('/api/v1/finance/bank/aspsps?country=ES').flush({ data: [aspsp('BBVA')] });
    http.expectOne('/api/v1/finance/bank/aspsps?country=LT').flush({}, { status: 502, statusText: 'Bad Gateway' });
    expect((await result).map((item) => item.name)).toEqual(['BBVA']);
  });

  it('starts a connection and returns the bank authorization url', async () => {
    const url = TestBed.inject(BankService).connect({ name: 'BBVA', country: 'ES' });
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections' });
    expect(request.request.body).toEqual({ aspsp_name: 'BBVA', aspsp_country: 'ES' });
    request.flush({ data: { auth_url: 'https://bank.example/auth' } });
    expect(await url).toBe('https://bank.example/auth');
  });

  it('refreshes connections and accounts after linking', async () => {
    const changes = TestBed.inject(FinanceChanges);
    const notify = vi.spyOn(changes, 'notify');
    const linked = TestBed.inject(BankService).link('connection-bbva', [{ external_account_uid: 'uid-1', account_id: 'new' }]);
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections/connection-bbva/accounts' });
    expect(request.request.body).toEqual({ accounts: [{ external_account_uid: 'uid-1', account_id: 'new' }] });
    request.flush({ data: { id: 'connection-bbva' } });
    await linked;
    await tick();
    expect(notify).toHaveBeenCalledWith('bank', 'accounts');
  });

  it('deduplicates banks offered by both lists', () => {
    expect(mergeAspsps([aspsp('Revolut', 'LT')], [aspsp('Revolut', 'LT')])).toHaveLength(1);
  });
});
