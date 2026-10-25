import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { todayIso } from '@shared/dates/dates';
import { NEW_ACCOUNT } from '../../data-access/bank.models';
import { aBankCandidate, aBankConnection, anAccount } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { BankLinkPage, candidateSubtitle, defaultNewAccountName, duplicateTargets } from './bank-link-page';

describe('BankLinkPage', () => {
  let http: HttpTestingController;

  async function render(candidates = [aBankCandidate(), aBankCandidate({ external_account_uid: 'uid-card', name: null, type: 'CARD', suggested_account_type: 'credit_card', iban: null })], renovado: string | null = null) {
    http = configureFinanceTesting();
    const fixture = TestBed.createComponent(BankLinkPage);
    fixture.componentRef.setInput('id', 'connection-bbva');
    fixture.componentRef.setInput('renovado', renovado);
    TestBed.tick();
    http.expectOne('/api/v1/finance/bank/connections/connection-bbva').flush({ data: aBankConnection({ linked_accounts: [] }) });
    http.expectOne('/api/v1/finance/bank/connections/connection-bbva/accounts').flush({ data: candidates });
    flushAll(http, 'accounts', { data: [anAccount(), anAccount({ id: 'account-savings', name: 'Ahorro', type: 'savings' })], meta: { net_worth_cents: 0 } });
    await tick();
    flushAll(http, 'bank/connections', { data: [] });
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement, component: fixture.componentInstance };
  }

  it('defaults every bank account to a new account imported from today', async () => {
    const { element, component } = await render();
    expect(component['heading']()).toBe('Vincular cuentas de BBVA');
    expect(element.textContent).toContain('Cuenta Online');
    expect(element.textContent).toContain('•••• 1332 · EUR');
    const rows = component['rows'].getRawValue();
    expect(rows.map((row) => row.target)).toEqual([NEW_ACCOUNT, NEW_ACCOUNT]);
    expect(rows.map((row) => row.from)).toEqual([todayIso(), todayIso()]);
    expect(rows[1]).toMatchObject({ name: 'BBVA tarjeta de crédito', type: 'credit_card' });
  });

  it('keeps existing links and their import date', async () => {
    const { component } = await render(
      [aBankCandidate({ linked_account: { id: 'account-checking', name: 'Cuenta corriente', type: 'checking', sync_from_date: '2026-09-01' } })],
      '1',
    );
    expect(component['rows'].getRawValue()[0]).toMatchObject({ target: 'account-checking', from: '2026-09-01' });
    expect(component['renewed']()).toBe(true);
  });

  it('links to existing, new or no account and returns to the bank list', async () => {
    const { fixture, element, component } = await render();
    const navigate = vi.spyOn(TestBed.inject(Router), 'navigateByUrl').mockResolvedValue(true);
    const rows = component['rows'].controls;
    rows[0].patchValue({ target: 'account-checking', from: '2026-10-01' });
    rows[1].patchValue({ target: null });
    await fixture.whenStable();
    element.querySelector<HTMLFormElement>('form')!.dispatchEvent(new Event('submit'));
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections/connection-bbva/accounts' });
    expect(request.request.body).toEqual({
      accounts: [
        { external_account_uid: 'uid-1', account_id: 'account-checking', sync_from_date: '2026-10-01' },
        { external_account_uid: 'uid-card', account_id: null },
      ],
    });
    request.flush({ data: aBankConnection() });
    await tick();
    flushAll(http, 'bank/connections', { data: [] });
    flushAll(http, 'accounts', { data: [], meta: { net_worth_cents: 0 } });
    expect(navigate).toHaveBeenCalledWith('/finanzas/ajustes/bancos');
  });

  it('sends name and type for new accounts', async () => {
    const { component } = await render([aBankCandidate()]);
    vi.spyOn(TestBed.inject(Router), 'navigateByUrl').mockResolvedValue(true);
    component['rows'].controls[0].patchValue({ name: '  BBVA nómina ' });
    void component['save']();
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections/connection-bbva/accounts' });
    expect(request.request.body.accounts[0]).toEqual({
      external_account_uid: 'uid-1',
      account_id: NEW_ACCOUNT,
      sync_from_date: todayIso(),
      name: 'BBVA nómina',
      type: 'checking',
    });
    request.flush({ data: aBankConnection() });
    await tick();
    flushAll(http, 'bank/connections', { data: [] });
    flushAll(http, 'accounts', { data: [], meta: { net_worth_cents: 0 } });
  });

  it('blocks linking two bank accounts to the same app account', async () => {
    const { fixture, element, component } = await render();
    component['rows'].controls.forEach((row) => row.patchValue({ target: 'account-checking' }));
    await fixture.whenStable();
    expect(element.textContent).toContain('Esta cuenta ya está elegida');
    void component['save']();
    http.expectNone({ method: 'POST' });
  });

  it('helps describe and name bank accounts', () => {
    expect(duplicateTargets(['a', 'a', NEW_ACCOUNT, NEW_ACCOUNT, null, null])).toEqual(new Set(['a']));
    expect(defaultNewAccountName('Revolut', aBankCandidate({ name: 'EUR' }))).toBe('Revolut EUR');
    expect(candidateSubtitle(aBankCandidate({ iban: null, currency: null }))).toBe('');
  });
});
