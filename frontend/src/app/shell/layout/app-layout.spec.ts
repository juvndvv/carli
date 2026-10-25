import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideServiceWorker } from '@angular/service-worker';
import { provideAppModules } from '@core/modules/app-module';
import { provideQuickAdd, QuickAddRegistry } from '@core/quick-add';
import { financeManifest, financeQuickAdd } from '@finance/finance.manifest';
import { AppLayout } from './app-layout';

describe('AppLayout', () => {
  async function setup() {
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideRouter([]),
        provideHttpClient(),
        provideHttpClientTesting(),
        provideServiceWorker('ngsw-worker.js', { enabled: false }),
        provideAppModules([financeManifest]),
        provideQuickAdd(financeQuickAdd),
      ],
    });
    const fixture = TestBed.createComponent(AppLayout);
    const http = TestBed.inject(HttpTestingController);
    await fixture.whenStable();
    http.expectOne('/api/v1/modules').flush([{ id: 'finance', enabled: true }]);
    http.expectOne('/api/v1/notifications?page=1').flush({ data: [], meta: { current_page: 1, last_page: 1, unread_count: 0 } });
    http.expectOne('/api/v1/pending/summary').flush({ data: pendingSummary });
    await new Promise((resolve) => setTimeout(resolve));
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement, http };
  }

  let pendingSummary = { total: 0, by_module: [] as { module: string; module_name: string; type: string; count: number }[] };

  beforeEach(() => {
    pendingSummary = { total: 0, by_module: [] };
  });

  it('renders the sidebar with the finance sub-navigation and upcoming modules', async () => {
    const { element } = await setup();
    const sidebar = element.querySelector('app-sidebar')!.textContent!;
    for (const label of ['Inicio', 'Finanzas', 'Resumen', 'Movimientos', 'Cuentas', 'Presupuestos', 'Ajustes']) {
      expect(sidebar).toContain(label);
    }
    expect(sidebar).toContain('Tareas');
    expect(sidebar).toContain('Pronto');
  });

  it('renders five bottom navigation entries', async () => {
    const { element } = await setup();
    const labels = [...element.querySelectorAll('app-bottom-nav a')].map((link) => link.textContent!.trim());
    expect(labels).toEqual(['Inicio', 'Resumen', 'Movimientos', 'Presupuestos', 'Más']);
  });

  it('links to Pendientes with a counter in the sidebar and a dot on Más', async () => {
    pendingSummary = {
      total: 4,
      by_module: [{ module: 'finance', module_name: 'Finanzas', type: 'uncategorized_transaction', count: 4 }],
    };
    const { element } = await setup();
    const link = element.querySelector<HTMLAnchorElement>('app-sidebar a[href="/pendientes"]')!;
    expect(link.textContent).toContain('Pendientes');
    expect(link.querySelector('ui-badge')?.textContent?.trim()).toBe('4');
    expect(link.getAttribute('aria-label')).toBe('Pendientes (4)');
    const more = element.querySelector<HTMLAnchorElement>('app-bottom-nav a[href="/mas"]')!;
    expect(more.querySelector('.badge-dot')).not.toBeNull();
    expect(more.getAttribute('aria-label')).toBe('Más (4 pendientes)');
  });

  it('hides the pending counter when nothing is pending', async () => {
    const { element } = await setup();
    expect(element.querySelector('app-sidebar a[href="/pendientes"] ui-badge')).toBeNull();
    expect(element.querySelector('app-bottom-nav .badge-dot')).toBeNull();
  });

  it('shows the quick add FAB from the registry', async () => {
    const { element } = await setup();
    const fab = element.querySelector<HTMLButtonElement>('.fab')!;
    expect(fab.getAttribute('aria-label')).toBe('Nuevo movimiento');
    expect(TestBed.inject(QuickAddRegistry).primary()?.id).toBe('finance.transaction');
  });

  it('hides a module disabled on the server', async () => {
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideRouter([]),
        provideHttpClient(),
        provideHttpClientTesting(),
        provideServiceWorker('ngsw-worker.js', { enabled: false }),
        provideAppModules([financeManifest]),
        provideQuickAdd(financeQuickAdd),
      ],
    });
    const fixture = TestBed.createComponent(AppLayout);
    const http = TestBed.inject(HttpTestingController);
    await fixture.whenStable();
    http.expectOne('/api/v1/modules').flush({ data: [{ id: 'finance', enabled: false }] });
    http.expectOne('/api/v1/notifications?page=1').flush({ data: [], meta: { current_page: 1, last_page: 1, unread_count: 0 } });
    http.expectOne('/api/v1/pending/summary').flush({ data: { total: 0, by_module: [] } });
    await new Promise((resolve) => setTimeout(resolve));
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-sidebar').textContent).not.toContain('Movimientos');
    expect(fixture.nativeElement.querySelector('.fab')).toBeNull();
    expect(await TestBed.inject(QuickAddRegistry).open()).toBe(false);
  });
});
