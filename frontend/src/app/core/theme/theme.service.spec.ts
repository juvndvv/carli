import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { SessionStore } from '../auth/session.store';
import { THEME_STORAGE_KEY, ThemeService } from './theme.service';

type Listener = (event: MediaQueryListEvent) => void;

function installMatchMedia(prefersDark: boolean): { emit: (dark: boolean) => void } {
  const listeners: Listener[] = [];
  Object.defineProperty(window, 'matchMedia', {
    configurable: true,
    writable: true,
    value: (query: string) => ({
      matches: query.includes('dark') ? prefersDark : false,
      media: query,
      addEventListener: (_type: string, listener: Listener) => listeners.push(listener),
      removeEventListener: () => undefined,
    }),
  });
  return { emit: (dark) => listeners.forEach((listener) => listener({ matches: dark } as MediaQueryListEvent)) };
}

describe('ThemeService', () => {
  let http: HttpTestingController;

  function setup(): ThemeService {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    return TestBed.inject(ThemeService);
  }

  beforeEach(() => {
    localStorage.clear();
    document.documentElement.removeAttribute('data-theme');
  });

  afterEach(() => http?.verify());

  it('defaults to the system preference', () => {
    installMatchMedia(true);
    const theme = setup();
    TestBed.tick();
    expect(theme.preference()).toBe('system');
    expect(theme.effective()).toBe('dark');
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('follows system changes while on the system preference', () => {
    const media = installMatchMedia(false);
    const theme = setup();
    expect(theme.effective()).toBe('light');
    media.emit(true);
    expect(theme.effective()).toBe('dark');
  });

  it('restores the stored preference', () => {
    installMatchMedia(false);
    localStorage.setItem(THEME_STORAGE_KEY, 'dark');
    const theme = setup();
    TestBed.tick();
    expect(theme.preference()).toBe('dark');
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });

  it('persists locally and applies the attribute when set as a guest', () => {
    installMatchMedia(false);
    const theme = setup();
    theme.set('dark');
    TestBed.tick();
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBe('dark');
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
    http.expectNone('/api/v1/me/preferences');
  });

  it('saves the preference on the server when authenticated', () => {
    installMatchMedia(false);
    const theme = setup();
    TestBed.inject(SessionStore).setUser({
      id: '1',
      name: 'Juanda',
      email: 'juanda@example.com',
      two_factor_enabled: false,
      preferences: {},
    });
    TestBed.tick();
    theme.set('light');
    const request = http.expectOne('/api/v1/me/preferences');
    expect(request.request.method).toBe('PATCH');
    expect(request.request.body).toEqual({ theme: 'light' });
    request.flush({});
  });

  it('cycles light → dark → system', () => {
    installMatchMedia(false);
    localStorage.setItem(THEME_STORAGE_KEY, 'light');
    const theme = setup();
    theme.cycle();
    expect(theme.preference()).toBe('dark');
    theme.cycle();
    expect(theme.preference()).toBe('system');
    TestBed.tick();
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('adopts the theme stored in the user preferences', () => {
    installMatchMedia(false);
    const theme = setup();
    TestBed.inject(SessionStore).setUser({
      id: '1',
      name: 'Juanda',
      email: 'juanda@example.com',
      two_factor_enabled: false,
      preferences: { theme: 'dark' },
    });
    TestBed.tick();
    expect(theme.preference()).toBe('dark');
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBe('dark');
  });

  it('keeps a choice made before the session loads and syncs it to the server', () => {
    installMatchMedia(false);
    localStorage.setItem(THEME_STORAGE_KEY, 'dark');
    const theme = setup();
    theme.set('system');
    TestBed.inject(SessionStore).setUser({
      id: '1',
      name: 'Juanda',
      email: 'juanda@example.com',
      two_factor_enabled: false,
      preferences: { theme: 'dark' },
    });
    TestBed.tick();
    expect(theme.preference()).toBe('system');
    const request = http.expectOne('/api/v1/me/preferences');
    expect(request.request.body).toEqual({ theme: 'system' });
    request.flush({});
  });
});
