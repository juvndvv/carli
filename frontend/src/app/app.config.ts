import { provideHttpClient, withFetch, withInterceptors, withXsrfConfiguration } from '@angular/common/http';
import {
  ApplicationConfig,
  isDevMode,
  provideBrowserGlobalErrorListeners,
  provideZonelessChangeDetection,
} from '@angular/core';
import { provideRouter, withComponentInputBinding, withInMemoryScrolling, withRouterConfig } from '@angular/router';
import { provideServiceWorker } from '@angular/service-worker';
import { apiInterceptor, XSRF_COOKIE_NAME, XSRF_HEADER_NAME } from '@core/http/api.interceptor';
import { provideAppLocale } from '@core/locale';
import { provideAppModules } from '@core/modules/app-module';
import { provideQuickAdd } from '@core/quick-add';
import { financeQuickAdd } from '@finance/finance.manifest';
import { APP_MODULE_MANIFESTS } from './app-modules';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideZonelessChangeDetection(),
    provideAppLocale(),
    provideRouter(
      routes,
      withComponentInputBinding(),
      withInMemoryScrolling({ scrollPositionRestoration: 'top' }),
      withRouterConfig({ paramsInheritanceStrategy: 'always' }),
    ),
    provideHttpClient(
      withFetch(),
      withXsrfConfiguration({ cookieName: XSRF_COOKIE_NAME, headerName: XSRF_HEADER_NAME }),
      withInterceptors([apiInterceptor]),
    ),
    provideAppModules(APP_MODULE_MANIFESTS),
    provideQuickAdd(financeQuickAdd),
    provideServiceWorker('ngsw-worker.js', {
      enabled: !isDevMode(),
      registrationStrategy: 'registerWhenStable:30000',
    }),
  ],
};
