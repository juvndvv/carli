import { registerLocaleData } from '@angular/common';
import localeEs from '@angular/common/locales/es';
import { DEFAULT_CURRENCY_CODE, EnvironmentProviders, LOCALE_ID, makeEnvironmentProviders } from '@angular/core';

export const APP_LOCALE = 'es-ES';

export function provideAppLocale(): EnvironmentProviders {
  registerLocaleData(localeEs, APP_LOCALE);
  return makeEnvironmentProviders([
    { provide: LOCALE_ID, useValue: APP_LOCALE },
    { provide: DEFAULT_CURRENCY_CODE, useValue: 'EUR' },
  ]);
}
