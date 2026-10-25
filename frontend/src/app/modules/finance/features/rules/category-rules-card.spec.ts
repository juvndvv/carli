import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ToastService } from '@ui/toast/toast.service';
import { aCategoryRule } from '../../testing/finance-fixtures';
import { configureFinanceTesting, tick } from '../../testing/finance-testing';
import { CategoryRulesCard, ruleCategoryLabel } from './category-rules-card';

describe('CategoryRulesCard', () => {
  let http: HttpTestingController;

  async function render(rules = [aCategoryRule(), aCategoryRule({ id: 'rule-nomina', pattern: 'ACME', kind: 'income', category: null })]) {
    http = configureFinanceTesting();
    const fixture = TestBed.createComponent(CategoryRulesCard);
    TestBed.tick();
    http.expectOne('/api/v1/finance/category-rules').flush({ data: rules });
    await tick();
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement };
  }

  it('lists the rules with their category', async () => {
    const { element } = await render();
    const text = element.textContent ?? '';
    expect(text).toContain('MERCADONA');
    expect(text).toContain('Alimentación › Supermercado');
    expect(text).toContain('Categoría eliminada · ingreso');
  });

  it('offers to retry when the rules cannot be loaded', async () => {
    http = configureFinanceTesting();
    const fixture = TestBed.createComponent(CategoryRulesCard);
    TestBed.tick();
    http.expectOne('/api/v1/finance/category-rules').flush({}, { status: 500, statusText: 'Error' });
    await tick();
    await fixture.whenStable();
    const element = fixture.nativeElement as HTMLElement;
    expect(element.textContent).toContain('No se han podido cargar las reglas');

    Array.from(element.querySelectorAll<HTMLButtonElement>('button')).find((item) => item.textContent?.trim() === 'Reintentar')!.click();
    TestBed.tick();
    http.expectOne('/api/v1/finance/category-rules').flush({ data: [aCategoryRule()] });
    await tick();
    await fixture.whenStable();
    expect(element.textContent).toContain('MERCADONA');
  });

  it('explains how rules are created when there are none', async () => {
    const { element } = await render([]);
    expect(element.textContent).toContain('Aún no hay reglas');
  });

  it('deletes a rule and can restore it', async () => {
    const { fixture, element } = await render();
    element.querySelector<HTMLButtonElement>('button[aria-label="Eliminar la regla MERCADONA"]')!.click();
    http.expectOne({ method: 'DELETE', url: '/api/v1/finance/category-rules/rule-mercadona' }).flush(null);
    await tick();
    http.expectOne('/api/v1/finance/category-rules').flush({ data: [] });
    const toasts = TestBed.inject(ToastService);
    const toast = toasts.active()[0];
    expect(toast.message).toBe('Regla «MERCADONA» eliminada');

    const undo = toasts.runAction(toast.id);
    const restore = http.expectOne({ method: 'POST', url: '/api/v1/finance/category-rules' });
    expect(restore.request.body).toEqual({ pattern: 'MERCADONA', category_id: 'category-super' });
    restore.flush({ data: aCategoryRule() });
    await undo;
    await tick();
    http.match('/api/v1/finance/category-rules').forEach((request) => request.flush({ data: [aCategoryRule()] }));
    await fixture.whenStable();
  });

  it('labels the rule category', () => {
    expect(ruleCategoryLabel(aCategoryRule())).toBe('Alimentación › Supermercado');
  });
});
