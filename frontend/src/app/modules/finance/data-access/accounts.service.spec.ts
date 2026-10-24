import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { anAccount } from '../testing/finance-fixtures';
import { configureFinanceTesting, tick } from '../testing/finance-testing';
import { AccountsService } from './accounts.service';

describe('AccountsService', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    http = configureFinanceTesting();
  });

  it('loads accounts with net worth and splits archived ones', async () => {
    const service = TestBed.inject(AccountsService);
    TestBed.tick();
    const request = http.expectOne((req) => req.url === '/api/v1/finance/accounts');
    expect(request.request.params.get('include_archived')).toBe('1');
    request.flush({
      data: [anAccount(), anAccount({ id: 'old', name: 'Vieja', archived: true })],
      meta: { net_worth_cents: 342865 },
    });
    await tick();
    expect(service.netWorth()).toBe(342865);
    expect(service.active().map((account) => account.id)).toEqual(['account-checking']);
    expect(service.archived().map((account) => account.id)).toEqual(['old']);
    expect(service.find('old')?.name).toBe('Vieja');
  });

  it('reloads the list after reconciling', async () => {
    const service = TestBed.inject(AccountsService);
    TestBed.tick();
    http.expectOne((req) => req.url === '/api/v1/finance/accounts').flush({ data: [anAccount()], meta: { net_worth_cents: 1 } });
    await tick();
    const promise = service.reconcile('account-checking', 340000, '2026-10-24');
    const request = http.expectOne('/api/v1/finance/accounts/account-checking/reconcile');
    expect(request.request.body).toEqual({ actual_balance_cents: 340000, date: '2026-10-24' });
    request.flush({ data: { account: anAccount(), adjustment: null, difference_cents: -2865, balance_cents: 340000 } });
    expect((await promise).difference_cents).toBe(-2865);
    TestBed.tick();
    expect(http.match((req) => req.url === '/api/v1/finance/accounts')).toHaveLength(1);
  });
});
