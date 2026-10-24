import { HttpClient, HttpErrorResponse, provideHttpClient, withInterceptors, withXsrfConfiguration } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { SessionStore } from '../auth/session.store';
import { apiInterceptor, CSRF_COOKIE_URL, XSRF_COOKIE_NAME, XSRF_HEADER_NAME } from './api.interceptor';

describe('apiInterceptor', () => {
  let http: HttpClient;
  let controller: HttpTestingController;
  let router: Router;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideZonelessChangeDetection(),
        provideRouter([]),
        provideHttpClient(
          withXsrfConfiguration({ cookieName: XSRF_COOKIE_NAME, headerName: XSRF_HEADER_NAME }),
          withInterceptors([apiInterceptor]),
        ),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    controller = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    document.cookie = `${XSRF_COOKIE_NAME}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
  });

  afterEach(() => controller.verify());

  it('sends credentials and JSON headers on same-origin requests', () => {
    http.get('/api/v1/me').subscribe();
    const request = controller.expectOne('/api/v1/me');
    expect(request.request.withCredentials).toBe(true);
    expect(request.request.headers.get('Accept')).toBe('application/json');
    expect(request.request.headers.get('X-Requested-With')).toBe('XMLHttpRequest');
    request.flush({});
  });

  it('leaves cross-origin requests untouched', () => {
    http.get('https://example.com/data').subscribe();
    const request = controller.expectOne('https://example.com/data');
    expect(request.request.withCredentials).toBe(false);
    expect(request.request.headers.has('X-Requested-With')).toBe(false);
    request.flush({});
  });

  it('redirects to /login and marks the session as guest on 401', async () => {
    const navigate = vi.spyOn(router, 'navigate').mockResolvedValue(true);
    const session = TestBed.inject(SessionStore);
    session.setUser({ id: '1', name: 'A', email: 'a@example.com', two_factor_enabled: false, preferences: {} });

    const result = firstValueFrom(http.get('/api/v1/finance/summary')).catch((error: unknown) => error);
    controller.expectOne('/api/v1/finance/summary').flush({ message: 'Unauthenticated.' }, { status: 401, statusText: 'Unauthorized' });

    const error = await result;
    expect(error).toBeInstanceOf(HttpErrorResponse);
    expect(session.status()).toBe('guest');
    expect(navigate).toHaveBeenCalledWith(['/login'], expect.anything());
  });

  it('refreshes the CSRF cookie and retries once on 419', async () => {
    const result = firstValueFrom(http.post('/api/v1/modules/finance', { enabled: true }));

    controller.expectOne('/api/v1/modules/finance').flush({ message: 'CSRF token mismatch.' }, { status: 419, statusText: 'Page Expired' });
    const csrf = controller.expectOne(CSRF_COOKIE_URL);
    expect(csrf.request.method).toBe('GET');
    document.cookie = `${XSRF_COOKIE_NAME}=fresh-token; path=/`;
    csrf.flush(null, { status: 204, statusText: 'No Content' });

    const retry = controller.expectOne('/api/v1/modules/finance');
    expect(retry.request.headers.get(XSRF_HEADER_NAME)).toBe('fresh-token');
    retry.flush({ ok: true });

    await expect(result).resolves.toEqual({ ok: true });
  });

  it('gives up after a second 419', async () => {
    const result = firstValueFrom(http.post('/api/v1/notifications/read', {})).catch((error: HttpErrorResponse) => error.status);

    controller.expectOne('/api/v1/notifications/read').flush({}, { status: 419, statusText: 'Page Expired' });
    controller.expectOne(CSRF_COOKIE_URL).flush(null, { status: 204, statusText: 'No Content' });
    controller.expectOne('/api/v1/notifications/read').flush({}, { status: 419, statusText: 'Page Expired' });

    await expect(result).resolves.toBe(419);
    controller.expectNone(CSRF_COOKIE_URL);
  });
});
