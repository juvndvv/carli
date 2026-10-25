import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { PendingStore } from '@core/pending/pending.store';
import { ToastService } from '@ui/toast/toast.service';
import { aCategory, aCategoryRule, aTransaction } from '../../testing/finance-fixtures';
import { configureFinanceTesting, flushAll, tick } from '../../testing/finance-testing';
import { appliedMessage, applySimilarLabel, SimilarCategorization, similarMessage } from './similar-categorization';

describe('SimilarCategorization', () => {
  let http: HttpTestingController;
  let toasts: ToastService;

  beforeEach(() => {
    http = configureFinanceTesting();
    toasts = TestBed.inject(ToastService);
  });

  it('stays quiet when nothing similar is waiting', async () => {
    const offered = TestBed.inject(SimilarCategorization).offer('tx-1', 'category-super');
    http.expectOne('/api/v1/finance/transactions/tx-1/similar').flush({ data: { count: 0, pattern: 'MERCADONA', transaction_ids: [] } });
    expect(await offered).toBe(false);
    expect(toasts.active()).toEqual([]);
  });

  it('stays quiet when the lookup fails', async () => {
    const offered = TestBed.inject(SimilarCategorization).offer('tx-1', 'category-super');
    http.expectOne('/api/v1/finance/transactions/tx-1/similar').flush({}, { status: 500, statusText: 'Error' });
    expect(await offered).toBe(false);
  });

  it('applies the category to the similar ones and remembers the rule', async () => {
    const offered = TestBed.inject(SimilarCategorization).offer('tx-1', 'category-super');
    http
      .expectOne('/api/v1/finance/transactions/tx-1/similar')
      .flush({ data: { count: 2, pattern: 'MERCADONA', transaction_ids: ['tx-2', 'tx-3'] } });
    expect(await offered).toBe(true);
    const toast = toasts.active()[0];
    expect(toast.message).toBe('Hay 2 movimientos parecidos sin categoría');
    expect(toast.action?.label).toBe('Aplicar a los 2 parecidos y recordar');

    const applied = toasts.runAction(toast.id);
    const request = http.expectOne({ method: 'POST', url: '/api/v1/finance/transactions/tx-1/categorize-similar' });
    expect(request.request.body).toEqual({ category_id: 'category-super', remember: true });
    request.flush({ data: { updated: 2, transaction: aTransaction(), rule: aCategoryRule() } });
    await tick();
    flushAll(http, 'categories', {
      data: [aCategory({ children: [aCategory({ id: 'category-super', name: 'Supermercado', parent_id: 'category-food' })] })],
    });
    await applied;
    expect(toasts.active()[0].message).toMatch(/^2 movimientos más en .* · regla «MERCADONA» guardada$/);
  });

  it('waits for the undo toast before offering', async () => {
    toasts.withUndo('Mercadona → Supermercado', () => undefined);
    const offered = TestBed.inject(SimilarCategorization).offer('tx-1', 'category-super');
    http
      .expectOne('/api/v1/finance/transactions/tx-1/similar')
      .flush({ data: { count: 2, pattern: 'MERCADONA', transaction_ids: ['tx-2', 'tx-3'] } });
    expect(await offered).toBe(true);
    expect(toasts.active().map((toast) => toast.message)).toEqual(['Mercadona → Supermercado']);

    toasts.dismiss(toasts.active()[0].id);
    expect(toasts.active()[0].message).toBe('Hay 2 movimientos parecidos sin categoría');
  });

  it('reloads the pending list once the similar ones are categorized', async () => {
    const store = TestBed.inject(PendingStore);
    const reload = vi.spyOn(store, 'reloadList').mockResolvedValue();
    const applied = TestBed.inject(SimilarCategorization).apply('tx-1', 'category-super');
    http
      .expectOne({ method: 'POST', url: '/api/v1/finance/transactions/tx-1/categorize-similar' })
      .flush({ data: { updated: 2, transaction: aTransaction(), rule: null } });
    await tick();
    flushAll(http, 'categories', { data: [] });
    await applied;
    expect(reload).toHaveBeenCalled();
  });

  it('words the offer for one or many', () => {
    expect(similarMessage(1)).toBe('Hay 1 movimiento parecido sin categoría');
    expect(applySimilarLabel(1)).toBe('Aplicar al parecido y recordar');
    expect(appliedMessage(1, null, 'Supermercado')).toBe('1 movimiento más en Supermercado');
  });
});
