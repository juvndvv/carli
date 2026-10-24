import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting, TestRequest } from '@angular/common/http/testing';
import { EnvironmentProviders, Provider, provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Routes } from '@angular/router';
import { provideFinanceIcons } from '../ui/finance-icons';

export function configureFinanceTesting(routes: Routes = [], extra: (Provider | EnvironmentProviders)[] = []): HttpTestingController {
  TestBed.configureTestingModule({
    providers: [
      provideZonelessChangeDetection(),
      provideRouter(routes),
      provideHttpClient(),
      provideHttpClientTesting(),
      provideFinanceIcons(),
      ...extra,
    ],
  });
  return TestBed.inject(HttpTestingController);
}

export function pending(http: HttpTestingController, path: string): TestRequest[] {
  return http.match((request) => request.url === `/api/v1/finance/${path}`);
}

export function flushAll(http: HttpTestingController, path: string, body: object): number {
  const requests = pending(http, path);
  requests.forEach((request) => request.flush(body));
  return requests.length;
}

export async function tick(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 0));
}
