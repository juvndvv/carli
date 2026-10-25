import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { PendingItem } from '@core/pending/pending.models';
import { PendingStore } from '@core/pending/pending.store';
import { aPendingItem } from '@core/pending/testing/pending-fixtures';
import { ToastService } from '@ui/toast/toast.service';
import { aCategory, aTransaction } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, pending, tick } from '../../testing/finance-testing';
import { CATEGORIZE_FOLLOW_UPS, CategorizedPendingTransaction } from './categorize-follow-up';
import { CategorizePendingAction, pendingCategoryKind, pendingTransactionId } from './categorize-pending-action';

const categories = [
  aCategory({ id: 'food', name: 'Alimentación', icon: 'utensils' }),
  aCategory({ id: 'fuel', name: 'Gasolina', icon: 'fuel' }),
  aCategory({ id: 'salary', name: 'Nómina', icon: 'briefcase', kind: 'income' }),
];

describe('pending transaction helpers', () => {
  it('reads the transaction id and kind from the item meta', () => {
    expect(pendingTransactionId(aPendingItem({ id: 'x', meta: { transaction_id: 'tx-9' } }))).toBe('tx-9');
    expect(pendingTransactionId(aPendingItem({ id: 'x', meta: {} }))).toBe('x');
    expect(pendingCategoryKind(aPendingItem({ meta: { kind: 'income' } }))).toBe('income');
    expect(pendingCategoryKind(aPendingItem({ meta: {} }))).toBe('expense');
  });
});

describe('CategorizePendingAction', () => {
  let http: HttpTestingController;
  const followUp = vi.fn<(event: CategorizedPendingTransaction) => void>();

  beforeEach(() => {
    followUp.mockReset();
    http = configureFinanceTesting([], [{ provide: CATEGORIZE_FOLLOW_UPS, useValue: [followUp] }]);
  });

  async function render(item: PendingItem = aPendingItem()) {
    const fixture = TestBed.createComponent(CategorizePendingAction);
    fixture.componentRef.setInput('item', item);
    TestBed.tick();
    flushAll(http, 'categories', { data: categories });
    await tick();
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement };
  }

  async function openPicker(element: HTMLElement, fixture: { whenStable: () => Promise<unknown> }) {
    element.querySelector<HTMLButtonElement>('button')!.click();
    await fixture.whenStable();
    flushAll(http, 'categories', { data: categories });
    await tick();
    await fixture.whenStable();
    return Array.from(element.querySelectorAll<HTMLButtonElement>('ui-category-picker button'));
  }

  it('offers only categories of the transaction kind', async () => {
    const { fixture, element } = await render(aPendingItem({ meta: { transaction_id: 'tx-1', kind: 'income' } }));
    const options = await openPicker(element, fixture);
    expect(options.map((option) => option.textContent?.trim())).toEqual(['Nómina']);
  });

  it('saves the category, resolves the item and runs the follow-ups', async () => {
    const store = TestBed.inject(PendingStore);
    const resolve = vi.spyOn(store, 'resolve');
    const toast = vi.spyOn(TestBed.inject(ToastService), 'withUndo');
    const item = aPendingItem();
    const { fixture, element } = await render(item);

    const options = await openPicker(element, fixture);
    expect(options.map((option) => option.textContent?.trim())).toEqual(['Alimentación', 'Gasolina']);
    options[1].click();

    const [request] = pending(http, 'transactions/tx-1');
    expect(request.request.method).toBe('PATCH');
    expect(request.request.body).toEqual({ category_id: 'fuel' });
    request.flush({ data: aTransaction({ category_id: 'fuel' }), meta: { periods_changed: false } });
    await tick();

    expect(resolve).toHaveBeenCalledWith(item);
    expect(toast).toHaveBeenCalledWith('Mercadona → Gasolina', expect.any(Function));
    expect(followUp).toHaveBeenCalledWith({ item, transactionId: 'tx-1', categoryId: 'fuel', kind: 'expense' });
  });

  it('keeps the item when saving fails', async () => {
    const resolve = vi.spyOn(TestBed.inject(PendingStore), 'resolve');
    const error = vi.spyOn(TestBed.inject(ToastService), 'error');
    const { fixture, element } = await render();

    (await openPicker(element, fixture))[0].click();
    pending(http, 'transactions/tx-1')[0].flush(
      { message: 'Categoría no válida.', errors: { category_id: ['Categoría no válida.'] } },
      { status: 422, statusText: 'Unprocessable' },
    );
    await tick();

    expect(resolve).not.toHaveBeenCalled();
    expect(error).toHaveBeenCalledWith('Categoría no válida.');
    expect(followUp).not.toHaveBeenCalled();
  });
});
