import { computed, Injectable, signal } from '@angular/core';
import { CurrentUser } from './auth.models';

export type SessionStatus = 'unknown' | 'authenticated' | 'guest';

@Injectable({ providedIn: 'root' })
export class SessionStore {
  private readonly currentUser = signal<CurrentUser | null>(null);
  private readonly currentStatus = signal<SessionStatus>('unknown');

  readonly user = this.currentUser.asReadonly();
  readonly status = this.currentStatus.asReadonly();
  readonly isAuthenticated = computed(() => this.currentStatus() === 'authenticated');
  readonly firstName = computed(() => this.currentUser()?.name.split(' ')[0] ?? '');

  setUser(user: CurrentUser): void {
    this.currentUser.set(user);
    this.currentStatus.set('authenticated');
  }

  patchUser(patch: Partial<CurrentUser>): void {
    this.currentUser.update((user) => (user ? { ...user, ...patch } : user));
  }

  markGuest(): void {
    this.currentUser.set(null);
    this.currentStatus.set('guest');
  }
}
