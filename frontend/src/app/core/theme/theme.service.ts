import { DOCUMENT } from '@angular/common';
import { computed, DestroyRef, effect, inject, Injectable, signal, untracked } from '@angular/core';
import { ThemePreference } from '../auth/auth.models';
import { AuthService } from '../auth/auth.service';

export type EffectiveTheme = 'light' | 'dark';

export const THEME_STORAGE_KEY = 'pa-theme';

const THEME_ORDER: ThemePreference[] = ['light', 'dark', 'system'];

const THEME_COLORS: Record<EffectiveTheme, string> = { light: '#FFFFFF', dark: '#212121' };

export const isThemePreference = (value: unknown): value is ThemePreference =>
  value === 'system' || value === 'light' || value === 'dark';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly document = inject(DOCUMENT);
  private readonly auth = inject(AuthService);
  private readonly media = this.document.defaultView?.matchMedia?.('(prefers-color-scheme: dark)') ?? null;
  private readonly systemDark = signal(this.media?.matches ?? false);
  private readonly selected = signal<ThemePreference>(this.readStoredPreference());
  private unsyncedLocalChange = false;

  readonly preference = this.selected.asReadonly();
  readonly effective = computed<EffectiveTheme>(() => {
    const preference = this.selected();
    if (preference === 'system') {
      return this.systemDark() ? 'dark' : 'light';
    }
    return preference;
  });
  readonly icon = computed(() => ({ light: 'sun', dark: 'moon', system: 'monitor' })[this.selected()]);
  readonly label = computed(() => ({ light: 'Claro', dark: 'Oscuro', system: 'Sistema' })[this.selected()]);

  constructor() {
    const listener = (event: MediaQueryListEvent) => this.systemDark.set(event.matches);
    this.media?.addEventListener?.('change', listener);
    inject(DestroyRef).onDestroy(() => this.media?.removeEventListener?.('change', listener));

    effect(() => this.apply(this.selected(), this.effective()));

    effect(() => {
      const serverPreference = this.auth.user()?.preferences.theme;
      if (isThemePreference(serverPreference)) {
        untracked(() => this.reconcileWithServer(serverPreference));
      }
    });
  }

  set(preference: ThemePreference): void {
    this.selected.set(preference);
    this.store(preference);
    if (this.auth.isAuthenticated()) {
      this.unsyncedLocalChange = false;
      this.auth.updatePreferences({ theme: preference }).catch(() => undefined);
    } else {
      this.unsyncedLocalChange = true;
    }
  }

  cycle(): void {
    const index = THEME_ORDER.indexOf(this.selected());
    this.set(THEME_ORDER[(index + 1) % THEME_ORDER.length]);
  }

  private reconcileWithServer(serverPreference: ThemePreference): void {
    const local = this.selected();
    if (serverPreference !== local && this.unsyncedLocalChange) {
      this.auth.updatePreferences({ theme: local }).catch(() => undefined);
    } else if (serverPreference !== local) {
      this.selected.set(serverPreference);
      this.store(serverPreference);
    }
    this.unsyncedLocalChange = false;
  }

  private apply(preference: ThemePreference, effective: EffectiveTheme): void {
    const root = this.document.documentElement;
    if (preference === 'system') {
      root.removeAttribute('data-theme');
    } else {
      root.setAttribute('data-theme', preference);
    }
    this.document
      .querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]')
      .forEach((meta) => meta.setAttribute('content', THEME_COLORS[effective]));
  }

  private readStoredPreference(): ThemePreference {
    try {
      const stored = this.document.defaultView?.localStorage.getItem(THEME_STORAGE_KEY);
      return isThemePreference(stored) ? stored : 'system';
    } catch {
      return 'system';
    }
  }

  private store(preference: ThemePreference): void {
    try {
      this.document.defaultView?.localStorage.setItem(THEME_STORAGE_KEY, preference);
    } catch {
      return;
    }
  }
}
