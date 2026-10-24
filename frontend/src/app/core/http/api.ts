import { HttpContextToken } from '@angular/common/http';
import { map, OperatorFunction } from 'rxjs';

export const API_BASE = '/api/v1';

export const apiUrl = (path: string): string => `${API_BASE}/${path.replace(/^\//, '')}`;

export const SKIP_AUTH_REDIRECT = new HttpContextToken<boolean>(() => false);

export const CSRF_RETRIED = new HttpContextToken<boolean>(() => false);

export interface ApiValidationError {
  message: string;
  errors?: Record<string, string[]>;
}

export interface CursorPage<T> {
  data: T[];
  next_cursor: string | null;
}

type Wrapped<T> = T | { data: T };

export function unwrapData<T>(): OperatorFunction<Wrapped<T>, T> {
  return map((response) => {
    if (response !== null && typeof response === 'object' && !Array.isArray(response) && 'data' in response) {
      return (response as { data: T }).data;
    }
    return response as T;
  });
}

export function toCursorPage<T>(): OperatorFunction<unknown, CursorPage<T>> {
  return map((response) => {
    if (Array.isArray(response)) {
      return { data: response as T[], next_cursor: null };
    }
    const body = (response ?? {}) as {
      data?: T[];
      next_cursor?: string | null;
      meta?: { next_cursor?: string | null };
    };
    return {
      data: body.data ?? [],
      next_cursor: body.next_cursor ?? body.meta?.next_cursor ?? null,
    };
  });
}

export function firstValidationMessage(error: unknown, fallback: string): string {
  const body = (error as { error?: ApiValidationError } | null)?.error;
  if (body?.errors) {
    const first = Object.values(body.errors).flat()[0];
    if (first) {
      return first;
    }
  }
  return body?.message && body.message !== '' ? body.message : fallback;
}
