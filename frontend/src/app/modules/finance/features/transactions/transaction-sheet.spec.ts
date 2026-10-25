import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ToastService } from '@ui/toast/toast.service';
import { aCategory, anAccount, aTransaction, someSettings } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { FinanceSettings } from '../../data-access/finance.models';
import { TransactionSheetData } from './transaction-form';
import { bankOriginLabel, categorizedImport, TransactionSheet } from './transaction-sheet';

describe('TransactionSheet', () => {
  let http: HttpTestingController;
  let close: ReturnType<typeof vi.fn>;

  async function open(
    data: TransactionSheetData = {},
    settings: Partial<FinanceSettings> = { last_used_account_id: 'account-savings' },
  ) {
    close = vi.fn();
    http = configureFinanceTesting(
      [],
      [
        { provide: DIALOG_DATA, useValue: data },
        { provide: DialogRef, useValue: { close, config: { panelClass: [] } } },
      ],
    );
    const fixture = TestBed.createComponent(TransactionSheet);
    TestBed.tick();
    flushAll(http, 'accounts', {
      data: [anAccount(), anAccount({ id: 'account-savings', name: 'Ahorro', type: 'savings', icon: 'piggy-bank' })],
      meta: { net_worth_cents: 0 },
    });
    flushAll(http, 'categories', {
      data: [
        aCategory({ children: [aCategory({ id: 'category-super', name: 'Supermercado', parent_id: 'category-food', icon: 'shopping-cart' })] }),
        aCategory({ id: 'category-payroll', name: 'Nómina', kind: 'income', icon: 'briefcase', opens_period: true }),
      ],
    });
    flushAll(http, 'settings', { data: someSettings(settings) });
    flushAll(http, 'tags', { data: [] });
    flushAll(http, 'contacts', { data: [{ id: 'ana', name: 'Ana', archived: false, balance_cents: 0 }] });
    await tick();
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement, component: fixture.componentInstance };
  }

  function typeAmount(element: HTMLElement, text: string): void {
    const input = element.querySelector<HTMLInputElement>('ui-money-input input')!;
    input.value = text;
    input.dispatchEvent(new Event('input'));
  }

  function submit(element: HTMLElement): void {
    element.querySelector<HTMLFormElement>('form')!.dispatchEvent(new Event('submit'));
  }

  it('creates an expense with the last used account and the picked category', async () => {
    const { fixture, element } = await open();
    expect(element.textContent).toContain('Nuevo movimiento');
    expect(element.querySelector('ui-select .label')!.textContent).toContain('Ahorro');
    typeAmount(element, '42,50');
    const category = Array.from(element.querySelectorAll<HTMLButtonElement>('ui-category-picker button')).find((button) =>
      button.textContent!.includes('Supermercado'),
    )!;
    category.click();
    await fixture.whenStable();
    submit(element);
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/transactions' });
    expect(request.request.body).toMatchObject({
      account_id: 'account-savings',
      kind: 'expense',
      amount_cents: -4250,
      category_id: 'category-super',
      status: 'cleared',
      tags: [],
    });
    expect(request.request.body.shares).toBeUndefined();
    request.flush({ data: aTransaction(), meta: { periods_changed: false } });
    await tick();
    expect(close).toHaveBeenCalledWith({ action: 'saved', transaction: aTransaction() });
    expect(TestBed.inject(ToastService).active()[0].message).toBe('Movimiento guardado');
    expect(TestBed.inject(ToastService).active()[0].action?.label).toBe('Deshacer');
  });

  it('prefers the chosen default account over the last used one', async () => {
    const { element } = await open({}, { default_account_id: 'account-checking', last_used_account_id: 'account-savings' });
    expect(element.querySelector('ui-select .label')!.textContent).not.toContain('Ahorro');
    expect(element.querySelector('ui-select .label')!.textContent).toContain(anAccount().name);
  });

  it('does not submit without an amount', async () => {
    const { fixture, element } = await open();
    submit(element);
    await fixture.whenStable();
    http.expectNone('/api/v1/finance/transactions');
    expect(element.textContent).toContain('Introduce un importe mayor que 0.');
  });

  it('creates a transfer between two accounts', async () => {
    const { fixture, element, component } = await open({ preset: { kind: 'transfer', accountId: 'account-checking' } });
    await fixture.whenStable();
    expect(component['form'].controls.toAccountId.value).toBe('account-savings');
    typeAmount(element, '500');
    submit(element);
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/transfers' });
    expect(request.request.body).toMatchObject({
      from_account_id: 'account-checking',
      to_account_id: 'account-savings',
      amount_cents: 50000,
    });
    const leg = aTransaction({ kind: 'transfer', amount_cents: -50000 });
    request.flush({ data: { transfer_group_id: 'g', from: leg, to: { ...leg, id: 'tx-2', amount_cents: 50000 } } });
    await tick();
    expect(close).toHaveBeenCalled();
  });

  it('shares an expense equally with a contact', async () => {
    const { fixture, element, component } = await open();
    typeAmount(element, '80');
    component['form'].controls.shareEnabled.setValue(true);
    component['form'].controls.categoryId.setValue('category-food');
    component['toggleShare']('ana');
    component['showMore'].set(true);
    await fixture.whenStable();
    expect(element.textContent).toContain('Ana te debe 40,00');
    submit(element);
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/transactions' });
    expect(request.request.body.shares).toEqual({ mode: 'equal', include_self: true, items: [{ contact_id: 'ana' }] });
    request.flush({ data: aTransaction(), meta: { periods_changed: false } });
    await tick();
  });

  it('edits a movement without resending untouched shares and deletes with undo', async () => {
    const transaction = aTransaction({ tags: ['casa'] });
    const { element, component } = await open({ transaction });
    expect(element.textContent).toContain('Editar movimiento');
    expect(component['form'].controls.amount.value).toBe(4250);
    component['form'].controls.description.setValue('Compra semanal');
    submit(element);
    const update = http.expectOne({ method: 'PATCH', url: '/api/v1/finance/transactions/tx-1' });
    expect(update.request.body).toMatchObject({ description: 'Compra semanal', amount_cents: -4250, tags: ['casa'] });
    expect('shares' in update.request.body).toBe(false);
    expect('splits' in update.request.body).toBe(false);
    update.flush({ data: transaction, meta: { periods_changed: true } });
    await tick();
    expect(TestBed.inject(ToastService).active()[0].message).toBe('Cambios guardados · periodos recalculados');

    const remove = element.querySelector<HTMLButtonElement>('button[aria-label="Eliminar movimiento"]')!;
    remove.click();
    http.expectOne({ method: 'DELETE', url: '/api/v1/finance/transactions/tx-1' }).flush({ meta: { periods_changed: false } });
    await tick();
    const toast = TestBed.inject(ToastService).active()[0];
    expect(toast.message).toBe('Movimiento eliminado');
    expect(toast.action?.label).toBe('Deshacer');
  });

  it('warns that periods were recalculated when deleting and restoring a payroll', async () => {
    const transaction = aTransaction({ kind: 'income', amount_cents: 200000, category_id: 'category-payroll' });
    const { element } = await open({ transaction });
    element.querySelector<HTMLButtonElement>('button[aria-label="Eliminar movimiento"]')!.click();
    http.expectOne({ method: 'DELETE', url: '/api/v1/finance/transactions/tx-1' }).flush({ meta: { periods_changed: true } });
    await tick();
    const toasts = TestBed.inject(ToastService);
    const toast = toasts.active()[0];
    expect(toast.message).toBe('Movimiento eliminado · periodos recalculados');

    const undo = toasts.runAction(toast.id);
    http
      .expectOne({ method: 'POST', url: '/api/v1/finance/transactions/tx-1/restore' })
      .flush({ data: transaction, meta: { periods_changed: true } });
    await undo;
    expect(toasts.active()[0].message).toBe('Movimiento restaurado · periodos recalculados');
  });

  it('offers to categorize similar imports after categorizing a bank movement', async () => {
    const transaction = aTransaction({
      category_id: null,
      category: null,
      uncategorized: true,
      source: 'bank',
      bank: { aspsp_name: 'BBVA' },
    });
    const { element, component } = await open({ transaction });
    expect(element.textContent).toContain('Importado de BBVA');
    const { kind, amount, accountId, date } = component['form'].controls;
    expect([kind, amount, accountId, date].every((control) => control.disabled)).toBe(true);
    component['form'].controls.categoryId.setValue('category-super');
    submit(element);
    const update = http.expectOne({ method: 'PATCH', url: '/api/v1/finance/transactions/tx-1' });
    expect(update.request.body).toMatchObject({
      account_id: transaction.account_id,
      kind: transaction.kind,
      amount_cents: transaction.amount_cents,
      date: transaction.date,
      category_id: 'category-super',
    });
    update
      .flush({ data: aTransaction({ category_id: 'category-super', source: 'bank' }), meta: { periods_changed: false } });
    await tick();
    http
      .expectOne({ method: 'GET', url: '/api/v1/finance/transactions/tx-1/similar' })
      .flush({ data: { count: 3, pattern: 'MERCADONA', transaction_ids: ['a', 'b', 'c'] } });
    await tick();
    const toast = TestBed.inject(ToastService).active()[0];
    expect(toast.message).toBe('Hay 3 movimientos parecidos sin categoría');
    expect(toast.action?.label).toBe('Aplicar a los 3 parecidos y recordar');
  });
});

describe('transaction sheet helpers', () => {
  it('detects a movement that just got its first category', () => {
    const before = aTransaction({ category_id: null, category: null });
    expect(categorizedImport(before, aTransaction())).toBe(true);
    expect(categorizedImport(null, aTransaction())).toBe(false);
    expect(categorizedImport(aTransaction(), aTransaction())).toBe(false);
    expect(categorizedImport(before, aTransaction({ category_id: null }))).toBe(false);
  });

  it('labels the bank origin', () => {
    expect(bankOriginLabel(aTransaction())).toBeNull();
    expect(bankOriginLabel(aTransaction({ source: 'bank', bank: null }))).toBe('Importado del banco');
    expect(bankOriginLabel(aTransaction({ source: 'bank', bank: { aspsp_name: 'Revolut' } }))).toBe('Importado de Revolut');
  });
});
