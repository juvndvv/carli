import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideAppModules } from '@core/modules/app-module';
import { PendingStore } from '@core/pending/pending.store';
import { aSummary } from '@core/pending/testing/pending-fixtures';
import { financeManifest } from '@finance/finance.manifest';
import { AppPendingHomeCard } from './pending-home-card';

describe('AppPendingHomeCard', () => {
  async function setup(summary: ReturnType<typeof aSummary>) {
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideRouter([]),
        provideHttpClient(),
        provideHttpClientTesting(),
        provideAppModules([financeManifest]),
      ],
    });
    const http = TestBed.inject(HttpTestingController);
    const refresh = TestBed.inject(PendingStore).refreshSummary();
    http.expectOne('/api/v1/pending/summary').flush({ data: summary });
    await refresh;
    const fixture = TestBed.createComponent(AppPendingHomeCard);
    await fixture.whenStable();
    return fixture.nativeElement as HTMLElement;
  }

  it('summarises each pending type with a filtered link', async () => {
    const element = await setup(aSummary(7, 1));
    expect(element.textContent).toContain('8 elementos por revisar');
    const rows = Array.from(element.querySelectorAll<HTMLAnchorElement>('a[ui-list-item]'));
    expect(rows.map((row) => row.querySelector('.title')?.textContent)).toEqual([
      '7 movimientos por categorizar',
      '1 recurrente por confirmar',
    ]);
    expect(rows[0].getAttribute('href')).toBe('/pendientes?modulo=finance&tipo=uncategorized_transaction');
  });

  it('renders nothing when there is nothing pending', async () => {
    const element = await setup({ total: 0, by_module: [] });
    expect(element.querySelector('ui-card')).toBeNull();
  });
});
