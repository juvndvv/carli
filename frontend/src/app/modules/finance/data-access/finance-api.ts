import { HttpParams } from '@angular/common/http';
import { apiUrl } from '@core/http/api';

export const FINANCE_API = 'finance';

export const financeUrl = (path: string): string => apiUrl(`${FINANCE_API}/${path.replace(/^\//, '')}`);

export type QueryValue = string | number | boolean | null | undefined | readonly (string | number)[];

export function toHttpParams(query: Record<string, QueryValue>): HttpParams {
  let params = new HttpParams();
  for (const [key, value] of Object.entries(query)) {
    if (value === null || value === undefined || value === '') {
      continue;
    }
    if (Array.isArray(value)) {
      for (const item of value) {
        params = params.append(`${key}[]`, String(item));
      }
      continue;
    }
    params = params.set(key, String(value));
  }
  return params;
}

export function toQueryString(query: Record<string, QueryValue>): string {
  return toHttpParams(query).toString();
}
