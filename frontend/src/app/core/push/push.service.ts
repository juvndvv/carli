import { HttpClient } from '@angular/common/http';
import { computed, DestroyRef, inject, Injectable, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { SwPush } from '@angular/service-worker';
import { firstValueFrom } from 'rxjs';
import { apiUrl, unwrapData } from '../http/api';

export type PushPermission = NotificationPermission | 'unsupported';

interface PublicKeyResponse {
  public_key?: string;
  publicKey?: string;
  key?: string;
}

const supportedContentEncoding = (): string =>
  (globalThis as { PushManager?: { supportedContentEncodings?: readonly string[] } }).PushManager
    ?.supportedContentEncodings?.[0] ?? 'aes128gcm';

@Injectable({ providedIn: 'root' })
export class PushService {
  private readonly http = inject(HttpClient);
  private readonly swPush = inject(SwPush);
  private readonly router = inject(Router);
  private readonly subscription = signal<PushSubscription | null>(null);
  private readonly permissionState = signal<PushPermission>(this.readPermission());
  private readonly busyState = signal(false);

  readonly supported = this.swPush.isEnabled;
  readonly permission = this.permissionState.asReadonly();
  readonly subscribed = computed(() => this.subscription() !== null);
  readonly busy = this.busyState.asReadonly();

  constructor() {
    if (!this.swPush.isEnabled) {
      return;
    }
    const destroyRef = inject(DestroyRef);
    this.swPush.subscription
      .pipe(takeUntilDestroyed(destroyRef))
      .subscribe((subscription) => this.subscription.set(subscription));
    this.swPush.notificationClicks.pipe(takeUntilDestroyed(destroyRef)).subscribe(({ notification }) => {
      const url = (notification.data as { url?: string } | undefined)?.url;
      if (url) {
        this.openUrl(url);
      }
    });
  }

  async enable(): Promise<void> {
    if (!this.swPush.isEnabled) {
      throw new Error('push-unsupported');
    }
    this.busyState.set(true);
    try {
      const keyResponse = await firstValueFrom(
        this.http.get<PublicKeyResponse | { data: PublicKeyResponse }>(apiUrl('push/public-key')).pipe(unwrapData()),
      );
      const serverPublicKey = keyResponse.public_key ?? keyResponse.publicKey ?? keyResponse.key ?? '';
      const subscription = await this.swPush.requestSubscription({ serverPublicKey });
      this.permissionState.set(this.readPermission());
      await firstValueFrom(
        this.http.post(apiUrl('push-subscriptions'), {
          ...subscription.toJSON(),
          content_encoding: supportedContentEncoding(),
        }),
      );
      this.subscription.set(subscription);
    } finally {
      this.permissionState.set(this.readPermission());
      this.busyState.set(false);
    }
  }

  async disable(): Promise<void> {
    const current = this.subscription();
    this.busyState.set(true);
    try {
      if (current) {
        await firstValueFrom(
          this.http.delete(apiUrl('push-subscriptions'), { body: { endpoint: current.endpoint } }),
        );
      }
      await this.swPush.unsubscribe().catch(() => undefined);
      this.subscription.set(null);
    } finally {
      this.busyState.set(false);
    }
  }

  async sendTest(): Promise<void> {
    await firstValueFrom(this.http.post(apiUrl('notifications/test'), {}));
  }

  private openUrl(url: string): void {
    try {
      const target = new URL(url, window.location.origin);
      if (target.origin === window.location.origin) {
        void this.router.navigateByUrl(`${target.pathname}${target.search}${target.hash}`);
        return;
      }
    } catch {
      return;
    }
    window.open(url, '_blank', 'noopener');
  }

  private readPermission(): PushPermission {
    return typeof Notification === 'undefined' ? 'unsupported' : Notification.permission;
  }
}
