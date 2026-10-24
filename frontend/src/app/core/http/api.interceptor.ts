import {
  HttpContext,
  HttpErrorResponse,
  HttpEvent,
  HttpEventType,
  HttpHandlerFn,
  HttpInterceptorFn,
  HttpRequest,
  HttpXsrfTokenExtractor,
} from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, filter, Observable, switchMap, take, throwError } from 'rxjs';
import { SessionStore } from '../auth/session.store';
import { CSRF_RETRIED, SKIP_AUTH_REDIRECT } from './api';

export const CSRF_COOKIE_URL = '/sanctum/csrf-cookie';
export const XSRF_COOKIE_NAME = 'XSRF-TOKEN';
export const XSRF_HEADER_NAME = 'X-XSRF-TOKEN';

const isSameOrigin = (url: string): boolean => url.startsWith('/') && !url.startsWith('//');

export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  const session = inject(SessionStore);
  const xsrf = inject(HttpXsrfTokenExtractor);

  if (!isSameOrigin(req.url)) {
    return next(req);
  }

  const prepared = req.clone({
    withCredentials: true,
    setHeaders: {
      Accept: 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    },
  });

  return next(prepared).pipe(
    catchError((error: unknown) => {
      if (!(error instanceof HttpErrorResponse)) {
        return throwError(() => error);
      }
      if (error.status === 419 && !prepared.context.get(CSRF_RETRIED)) {
        return refreshCsrfAndRetry(prepared, next, xsrf);
      }
      if (error.status === 401 && !prepared.context.get(SKIP_AUTH_REDIRECT)) {
        session.markGuest();
        const current = router.url;
        if (!current.startsWith('/login')) {
          void router.navigate(['/login'], {
            queryParams: current && current !== '/' ? { redirect: current } : {},
          });
        }
      }
      return throwError(() => error);
    }),
  );
};

function refreshCsrfAndRetry(
  req: HttpRequest<unknown>,
  next: HttpHandlerFn,
  xsrf: HttpXsrfTokenExtractor,
): Observable<HttpEvent<unknown>> {
  const csrfRequest = new HttpRequest('GET', CSRF_COOKIE_URL, null, {
    withCredentials: true,
    context: new HttpContext().set(CSRF_RETRIED, true).set(SKIP_AUTH_REDIRECT, true),
  });
  return next(csrfRequest).pipe(
    filter((event) => event.type === HttpEventType.Response),
    take(1),
    switchMap(() => {
      const token = xsrf.getToken();
      const retried = req.clone({
        context: req.context.set(CSRF_RETRIED, true),
        setHeaders: token ? { [XSRF_HEADER_NAME]: token } : {},
      });
      return next(retried);
    }),
  );
}
