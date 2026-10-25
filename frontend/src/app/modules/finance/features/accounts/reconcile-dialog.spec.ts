import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { TestBed } from '@angular/core/testing';
import { aBankLink, anAccount } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { ReconcileDialog, reconcileStartingBalance } from './reconcile-dialog';

describe('ReconcileDialog', () => {
  it('starts from the bank balance on linked accounts', () => {
    expect(reconcileStartingBalance(anAccount())).toBe(342865);
    expect(reconcileStartingBalance(anAccount({ bank: aBankLink({ balance_cents: 343365 }) }))).toBe(343365);
    expect(reconcileStartingBalance(anAccount({ bank: aBankLink({ balance_cents: null }) }))).toBe(342865);
  });

  it('prefills the bank balance and shows the adjustment it would create', async () => {
    const account = anAccount({ bank: aBankLink({ balance_cents: 343365 }) });
    const http = configureFinanceTesting(
      [],
      [
        { provide: DIALOG_DATA, useValue: { account } },
        { provide: DialogRef, useValue: { close: vi.fn(), config: { panelClass: [] } } },
      ],
    );
    const fixture = TestBed.createComponent(ReconcileDialog);
    TestBed.tick();
    flushAll(http, 'accounts', { data: [account], meta: { net_worth_cents: 0 } });
    await tick();
    await fixture.whenStable();
    const text = (fixture.nativeElement as HTMLElement).textContent?.replace(/ /g, ' ') ?? '';
    expect(text).toContain('Precargado con el saldo que informa BBVA');
    expect(text).toContain('+5,00 €');
  });
});
