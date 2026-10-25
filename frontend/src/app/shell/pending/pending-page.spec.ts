import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ChangeDetectionStrategy, Component, inject, input, provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { AppModuleManifest, provideAppModules } from '@core/modules/app-module';
import { fallbackPendingDescriptor, PendingActions } from '@core/pending/pending-actions';
import { PendingItem } from '@core/pending/pending.models';
import { PendingStore } from '@core/pending/pending.store';
import { aPendingItem, aSummary } from '@core/pending/testing/pending-fixtures';
import { groupPendingItems, PendingPage } from './pending-page';

@Component({
  selector: 'test-resolve-action',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<button type="button" class="resolve" (click)="store.resolve(item())">Resolver {{ item().title }}</button>`,
})
class ResolveAction {
  protected readonly store = inject(PendingStore);
  readonly item = input.required<PendingItem>();
}

const testManifest: AppModuleManifest = {
  id: 'finance',
  name: 'Finanzas',
  icon: 'wallet',
  basePath: '/finanzas',
  routes: () => Promise.resolve([]),
  nav: [],
  pendingTypes: {
    uncategorized_transaction: {
      label: 'Movimientos por categorizar',
      icon: 'circle-dashed',
      countLabel: (count) => `${count} movimientos por categorizar`,
    },
    recurring_to_confirm: { label: 'Recurrentes por confirmar', icon: 'repeat', countLabel: (count) => `${count} recurrentes` },
  },
  pendingActions: { uncategorized_transaction: () => Promise.resolve(ResolveAction) },
};

const recurringItem = aPendingItem({
  type: 'recurring_to_confirm',
  id: 'tx-r',
  title: 'Netflix',
  subtitle: 'Cuenta corriente · Por confirmar',
  amount_cents: -1399,
  route: '/finanzas/recurrentes',
  meta: { rule_id: 'netflix' },
});

const settle = async () => {
  for (let index = 0; index < 4; index++) {
    await new Promise((resolve) => setTimeout(resolve));
    TestBed.tick();
  }
};

describe('groupPendingItems', () => {
  it('groups by module and type in arrival order with summary counts', () => {
    const groups = groupPendingItems(
      [aPendingItem(), aPendingItem({ id: 'tx-2' }), recurringItem],
      aSummary(5, 1).by_module,
      (_, type) => fallbackPendingDescriptor(type),
      () => ({ name: null, icon: 'wallet' }),
    );
    expect(groups).toHaveLength(1);
    expect(groups[0].name).toBe('Finanzas');
    expect(groups[0].types.map((group) => [group.type, group.count, group.items.length])).toEqual([
      ['uncategorized_transaction', 5, 2],
      ['recurring_to_confirm', 1, 1],
    ]);
  });
});

describe('PendingPage', () => {
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideRouter([
          { path: 'pendientes', component: PendingPage },
          { path: 'finanzas/recurrentes', children: [] },
        ]),
        provideHttpClient(),
        provideHttpClientTesting(),
        provideAppModules([testManifest]),
      ],
    });
    http = TestBed.inject(HttpTestingController);
  });

  async function render(url: string, items: PendingItem[], summary = aSummary(), hasMore = false) {
    const harness = await RouterTestingHarness.create();
    await harness.navigateByUrl(url);
    TestBed.tick();
    const list = http.expectOne((request) => request.url === '/api/v1/pending');
    list.flush({ data: items, meta: { has_more: hasMore, next_cursor: hasMore ? 'next' : null } });
    http.expectOne('/api/v1/pending/summary').flush({ data: summary });
    await settle();
    return { harness, element: harness.routeNativeElement as HTMLElement, list };
  }

  it('lists items grouped by type with the module action or a review link', async () => {
    const { element } = await render('/pendientes', [aPendingItem(), recurringItem]);

    const cards = Array.from(element.querySelectorAll('ui-card'));
    expect(cards.map((card) => card.querySelector('h2')?.textContent?.trim())).toEqual([
      'Movimientos por categorizar',
      'Recurrentes por confirmar',
    ]);
    expect(cards[0].textContent).toContain('2');
    expect(cards[0].textContent).toContain('Mercadona');
    expect(cards[0].textContent).toContain('BBVA · Importado del banco');
    expect(cards[0].querySelector('.resolve')?.textContent).toContain('Resolver Mercadona');
    expect(cards[1].querySelector('a[ui-button]')?.getAttribute('href')).toBe('/finanzas/recurrentes');
    expect(TestBed.inject(PendingStore).total()).toBe(3);
  });

  it('drops an item once its inline action resolves it', async () => {
    const { element } = await render('/pendientes', [aPendingItem(), aPendingItem({ id: 'tx-2', title: 'Lidl' }), recurringItem]);

    element.querySelector<HTMLButtonElement>('.resolve')!.click();
    await settle();

    const titles = Array.from(element.querySelectorAll('app-pending-item-row .title')).map((title) => title.textContent);
    expect(titles).toEqual(['Lidl', 'Netflix']);
    expect(TestBed.inject(PendingStore).count('finance', 'uncategorized_transaction')).toBe(1);
  });

  it('filters by module and type from the query params and offers chips', async () => {
    const { element, list } = await render('/pendientes?modulo=finance&tipo=recurring_to_confirm', [recurringItem]);

    expect(list.request.params.get('module')).toBe('finance');
    expect(list.request.params.get('type')).toBe('recurring_to_confirm');
    const chips = Array.from(element.querySelectorAll<HTMLButtonElement>('button[ui-chip]'));
    expect(chips.map((chip) => chip.textContent?.trim())).toEqual([
      'Todo (3)',
      'Movimientos por categorizar (2)',
      'Recurrentes por confirmar (1)',
    ]);
    expect(chips[2].getAttribute('aria-pressed')).toBe('true');

    chips[0].click();
    await settle();
    expect(TestBed.inject(Router).url).toBe('/pendientes');
    http.expectOne((request) => request.url === '/api/v1/pending' && !request.params.has('type'));
  });

  it('loads the next page with the cursor', async () => {
    const { element } = await render('/pendientes', [aPendingItem()], aSummary(), true);

    const more = Array.from(element.querySelectorAll<HTMLButtonElement>('button')).find((button) =>
      button.textContent?.includes('Cargar más'),
    )!;
    more.click();
    const next = http.expectOne((request) => request.url === '/api/v1/pending' && request.params.get('cursor') === 'next');
    next.flush({ data: [aPendingItem({ id: 'tx-3', title: 'Repsol' })], meta: { has_more: false, next_cursor: null } });
    await settle();

    expect(element.textContent).toContain('Repsol');
    expect(element.textContent).not.toContain('Cargar más');
  });

  it('shows an empty state when there is nothing to review', async () => {
    const { element } = await render('/pendientes', [], { total: 0, by_module: [] });

    expect(element.querySelector('ui-empty-state')?.textContent).toContain('Todo al día');
    expect(element.querySelectorAll('button[ui-chip]')).toHaveLength(0);
  });

  it('describes types without a manifest entry with a readable fallback', () => {
    const actions = TestBed.inject(PendingActions);
    expect(actions.describe('tasks', 'overdue_task').label).toBe('Overdue task');
    expect(actions.describe('finance', 'recurring_to_confirm').label).toBe('Recurrentes por confirmar');
    expect(actions.hasAction('finance', 'recurring_to_confirm')).toBe(false);
    expect(actions.hasAction('finance', 'uncategorized_transaction')).toBe(true);
  });
});
