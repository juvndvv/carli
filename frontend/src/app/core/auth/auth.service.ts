import { HttpClient, HttpContext } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { apiUrl, SKIP_AUTH_REDIRECT, unwrapData } from '../http/api';
import { CSRF_COOKIE_URL } from '../http/api.interceptor';
import {
  ActiveSession,
  Credentials,
  CurrentUser,
  LoginResult,
  TwoFactorAnswer,
  UserPreferences,
} from './auth.models';
import { SessionStore } from './session.store';

const silentContext = () => new HttpContext().set(SKIP_AUTH_REDIRECT, true);

interface RawUser extends Omit<CurrentUser, 'preferences' | 'two_factor_enabled'> {
  preferences?: UserPreferences | null;
  two_factor_enabled?: boolean;
  two_factor_confirmed_at?: string | null;
}

const normalizeUser = (raw: RawUser): CurrentUser => ({
  ...raw,
  two_factor_enabled: raw.two_factor_enabled ?? Boolean(raw.two_factor_confirmed_at),
  preferences: raw.preferences ?? {},
});

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly session = inject(SessionStore);
  private pendingPreferenceWrite: Promise<void> | null = null;
  private pendingMe: Promise<CurrentUser | null> | null = null;

  readonly user = this.session.user;
  readonly status = this.session.status;
  readonly isAuthenticated = this.session.isAuthenticated;

  ensureCsrfCookie(): Promise<unknown> {
    return firstValueFrom(this.http.get(CSRF_COOKIE_URL, { context: silentContext() }));
  }

  loadMe(): Promise<CurrentUser | null> {
    this.pendingMe ??= firstValueFrom(
      this.http.get<RawUser | { data: RawUser }>(apiUrl('me'), { context: silentContext() }).pipe(unwrapData()),
    )
      .then((raw) => {
        const user = normalizeUser(raw);
        this.session.setUser(user);
        return user;
      })
      .catch(() => {
        this.session.markGuest();
        return null;
      })
      .finally(() => {
        this.pendingMe = null;
      });
    return this.pendingMe;
  }

  async ensureSession(): Promise<boolean> {
    if (this.session.status() === 'unknown') {
      await this.loadMe();
    }
    return this.session.isAuthenticated();
  }

  async login(credentials: Credentials): Promise<LoginResult> {
    await this.ensureCsrfCookie();
    const response = await firstValueFrom(
      this.http.post<{ two_factor?: boolean } | null>('/login', credentials, { context: silentContext() }),
    );
    if (response?.two_factor) {
      return 'two_factor';
    }
    await this.loadMe();
    return 'authenticated';
  }

  async completeTwoFactor(answer: TwoFactorAnswer): Promise<void> {
    await firstValueFrom(this.http.post('/two-factor-challenge', answer, { context: silentContext() }));
    await this.loadMe();
  }

  async logout(): Promise<void> {
    try {
      await firstValueFrom(this.http.post('/logout', {}, { context: silentContext() }));
    } finally {
      this.session.markGuest();
    }
  }

  async updatePreferences(patch: UserPreferences): Promise<void> {
    const current = this.session.user();
    if (current) {
      this.session.patchUser({ preferences: { ...current.preferences, ...patch } });
    }
    const send = () => firstValueFrom(this.http.patch(apiUrl('me/preferences'), patch));
    const write = this.pendingPreferenceWrite ? this.pendingPreferenceWrite.then(send) : send();
    const settled = write.then(
      () => undefined,
      () => undefined,
    );
    this.pendingPreferenceWrite = settled;
    void settled.then(() => {
      if (this.pendingPreferenceWrite === settled) {
        this.pendingPreferenceWrite = null;
      }
    });
    await write;
  }

  async updateProfile(profile: { name: string; email: string }): Promise<void> {
    await firstValueFrom(this.http.put('/user/profile-information', profile));
    this.session.patchUser(profile);
  }

  async updatePassword(payload: {
    current_password: string;
    password: string;
    password_confirmation: string;
  }): Promise<void> {
    await firstValueFrom(this.http.put('/user/password', payload));
  }

  async confirmPassword(password: string): Promise<void> {
    await firstValueFrom(this.http.post('/user/confirm-password', { password }));
  }

  async passwordConfirmed(): Promise<boolean> {
    const response = await firstValueFrom(
      this.http.get<{ confirmed: boolean }>('/user/confirmed-password-status'),
    );
    return response.confirmed;
  }

  async enableTwoFactor(): Promise<void> {
    await firstValueFrom(this.http.post('/user/two-factor-authentication', {}));
  }

  async twoFactorQrCode(): Promise<{ svg: string; url: string }> {
    return firstValueFrom(this.http.get<{ svg: string; url: string }>('/user/two-factor-qr-code'));
  }

  async twoFactorSecretKey(): Promise<string> {
    const response = await firstValueFrom(this.http.get<{ secretKey: string }>('/user/two-factor-secret-key'));
    return response.secretKey;
  }

  async confirmTwoFactor(code: string): Promise<void> {
    await firstValueFrom(this.http.post('/user/confirmed-two-factor-authentication', { code }));
    this.session.patchUser({ two_factor_enabled: true });
  }

  async disableTwoFactor(): Promise<void> {
    await firstValueFrom(this.http.delete('/user/two-factor-authentication'));
    this.session.patchUser({ two_factor_enabled: false });
  }

  async recoveryCodes(): Promise<string[]> {
    return firstValueFrom(this.http.get<string[]>('/user/two-factor-recovery-codes'));
  }

  async regenerateRecoveryCodes(): Promise<string[]> {
    await firstValueFrom(this.http.post('/user/two-factor-recovery-codes', {}));
    return this.recoveryCodes();
  }

  async sessions(): Promise<ActiveSession[]> {
    return firstValueFrom(
      this.http.get<ActiveSession[] | { data: ActiveSession[] }>(apiUrl('me/sessions')).pipe(unwrapData()),
    );
  }

  async logoutOtherSessions(password: string): Promise<void> {
    await firstValueFrom(this.http.post(apiUrl('me/sessions/logout-others'), { password }));
  }
}
