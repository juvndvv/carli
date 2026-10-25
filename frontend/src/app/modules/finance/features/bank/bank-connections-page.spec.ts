import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { DialogService } from '@ui/dialog/dialog.service';
import { ToastService } from '@ui/toast/toast.service';
import { BankRedirect, SYNC_POLL_INTERVAL_MS } from '../../data-access/bank.service';
import { aBankConnection } from '../../testing/finance-fixtures';
import { configureFinanceTesting, tick } from '../../testing/finance-testing';
import { BankConnectionsPage, lastSyncLabel, linkedAccountLabel } from './bank-connections-page';

describe('BankConnectionsPage', () => {
  let http: HttpTestingController;
  const go = vi.fn<(url: string) => void>();

  async function render(connections = [aBankConnection()], error: string | null = null) {
    go.mockReset();
    http = configureFinanceTesting([], [{ provide: BankRedirect, useValue: { go } }]);
    const fixture = TestBed.createComponent(BankConnectionsPage);
    fixture.componentRef.setInput('error', error);
    TestBed.tick();
    http.match('/api/v1/finance/bank/connections').forEach((request) => request.flush({ data: connections }));
    http.match('/api/v1/finance/category-rules').forEach((request) => request.flush({ data: [] }));
    await tick();
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement };
  }

  function button(element: HTMLElement, label: string): HTMLButtonElement {
    const found = Array.from(element.querySelectorAll<HTMLButtonElement>('button')).find((item) => item.textContent?.trim() === label);
    if (!found) {
      throw new Error(`No button ${label}`);
    }
    return found;
  }

  afterEach(() => {
    vi.useRealTimers();
  });

  it('invites to connect a bank when there are none', async () => {
    const { element } = await render([]);
    expect(element.textContent).toContain('Conecta tu banco');
  });

  it('shows each connection with its state and linked accounts', async () => {
    const { element } = await render([
      aBankConnection(),
      aBankConnection({ id: 'revolut', aspsp_name: 'Revolut', expires_in_days: 3, linked_accounts: [] }),
      aBankConnection({ id: 'myinvestor', aspsp_name: 'MyInvestor', status: 'error', last_error: 'El banco no responde.' }),
      aBankConnection({ id: 'old', aspsp_name: 'ING', status: 'expired', expires_in_days: 0 }),
    ]);
    const text = element.textContent ?? '';
    expect(text).toContain('Activa');
    expect(text).toContain('Caduca en 3 días');
    expect(text).toContain('El banco no responde.');
    expect(text).toContain('Caducada');
    expect(text).toContain('Cuenta corriente · desde el 1 oct 2026');
    expect(text).toContain('Ninguna cuenta vinculada');
  });

  it('offers to retry when the banks cannot be loaded', async () => {
    http = configureFinanceTesting([], [{ provide: BankRedirect, useValue: { go } }]);
    const fixture = TestBed.createComponent(BankConnectionsPage);
    TestBed.tick();
    http.match('/api/v1/finance/bank/connections').forEach((request) => request.flush({}, { status: 500, statusText: 'Error' }));
    http.match('/api/v1/finance/category-rules').forEach((request) => request.flush({ data: [] }));
    await tick();
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    expect(element.textContent).toContain('No se han podido cargar los bancos');

    button(element, 'Reintentar').click();
    TestBed.tick();
    http.expectOne('/api/v1/finance/bank/connections').flush({ data: [] });
    await tick();
    await fixture.whenStable();
    expect(element.textContent).toContain('Conecta tu banco');
  });

  it('keeps waiting for the sync when one status check fails', async () => {
    const { fixture, element } = await render();
    vi.useFakeTimers();
    button(element, 'Sincronizar ahora').click();
    http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections/connection-bbva/sync' }).flush({ data: { queued: true } }, { status: 202, statusText: 'Accepted' });
    await vi.advanceTimersByTimeAsync(SYNC_POLL_INTERVAL_MS);
    http
      .expectOne({ method: 'GET', url: '/api/v1/finance/bank/connections/connection-bbva' })
      .error(new ProgressEvent('error'));
    await vi.advanceTimersByTimeAsync(SYNC_POLL_INTERVAL_MS);
    http
      .expectOne({ method: 'GET', url: '/api/v1/finance/bank/connections/connection-bbva' })
      .flush({ data: aBankConnection({ last_synced_at: '2026-10-25T13:30:00+00:00' }) });
    await vi.advanceTimersByTimeAsync(0);
    const toasts = TestBed.inject(ToastService).active();
    expect(toasts[0].message).toBe('BBVA sincronizado');
    expect(toasts[0].tone).toBe('default');
    vi.useRealTimers();
    http.match(() => true).forEach((request) => request.flush({ data: [] }));
    await fixture.whenStable();
  });

  it('explains a failed bank callback', async () => {
    const { element } = await render([], 'cancelado');
    expect(element.querySelector('[role="alert"]')?.textContent).toContain('Has cancelado la autorización');
  });

  it('syncs now and reports when the bank finished', async () => {
    const { fixture, element } = await render();
    vi.useFakeTimers();
    button(element, 'Sincronizar ahora').click();
    http.expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections/connection-bbva/sync' }).flush({ data: { queued: true } }, { status: 202, statusText: 'Accepted' });
    await vi.advanceTimersByTimeAsync(SYNC_POLL_INTERVAL_MS);
    http
      .expectOne({ method: 'GET', url: '/api/v1/finance/bank/connections/connection-bbva' })
      .flush({ data: aBankConnection({ last_synced_at: '2026-10-25T13:30:00+00:00' }) });
    await vi.advanceTimersByTimeAsync(0);
    expect(TestBed.inject(ToastService).active()[0].message).toBe('BBVA sincronizado');
    vi.useRealTimers();
    http.match(() => true).forEach((request) => request.flush({ data: [] }));
    await fixture.whenStable();
  });

  it('renews the consent by sending the user to the bank', async () => {
    const { element } = await render();
    button(element, 'Renovar').click();
    http
      .expectOne({ method: 'POST', url: '/api/v1/finance/bank/connections/connection-bbva/renew' })
      .flush({ data: { auth_url: 'https://bank.example/renew' } });
    await tick();
    expect(go).toHaveBeenCalledWith('https://bank.example/renew');
  });

  it('disconnects after confirming that imported movements are kept', async () => {
    const { element } = await render();
    const confirm = vi.spyOn(TestBed.inject(DialogService), 'confirm').mockResolvedValue(true);
    button(element, 'Desconectar').click();
    await tick();
    expect(confirm.mock.calls[0][0].message).toContain('Los movimientos ya importados se conservan');
    http.expectOne({ method: 'DELETE', url: '/api/v1/finance/bank/connections/connection-bbva' }).flush(null);
    await tick();
    expect(TestBed.inject(ToastService).active()[0].message).toBe('BBVA desconectado · los movimientos importados se conservan');
  });

  it('keeps the connection when the user cancels', async () => {
    const { element } = await render();
    vi.spyOn(TestBed.inject(DialogService), 'confirm').mockResolvedValue(false);
    button(element, 'Desconectar').click();
    await tick();
    http.expectNone({ method: 'DELETE' });
  });

  it('words the sync time and linked accounts', () => {
    expect(lastSyncLabel({ last_synced_at: null })).toBe('Aún no se ha sincronizado');
    expect(lastSyncLabel({ last_synced_at: '2026-10-10T11:00:00+00:00' }, new Date('2026-10-10T20:00:00+02:00'))).toBe(
      'Sincronizado hoy a las 13:00',
    );
    expect(linkedAccountLabel({ id: 'a', name: 'Ahorro', external_account_uid: 'x', sync_from_date: null })).toBe('Ahorro');
  });
});
