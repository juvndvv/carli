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
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement, http };
  }

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
    await new Promise((resolve) => setTimeout(resolve));
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-sidebar').textContent).not.toContain('Movimientos');
    expect(fixture.nativeElement.querySelector('.fab')).toBeNull();
    expect(await TestBed.inject(QuickAddRegistry).open()).toBe(false);
  });
});
