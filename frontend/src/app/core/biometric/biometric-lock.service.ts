import { DOCUMENT } from '@angular/common';
import { computed, inject, Injectable, signal } from '@angular/core';
import { App } from '@capacitor/app';
import { Capacitor } from '@capacitor/core';
import { BiometryType, NativeBiometric } from '@capgo/capacitor-native-biometric';

export const BIOMETRIC_LOCK_STORAGE_KEY = 'pa-biometric-lock';

export const BIOMETRIC_LOCK_GRACE_MS = 60_000;

const BIOMETRY_LABELS: Partial<Record<BiometryType, string>> = {
  [BiometryType.FACE_ID]: 'Face ID',
  [BiometryType.TOUCH_ID]: 'Touch ID',
};

@Injectable({ providedIn: 'root' })
export class BiometricLockService {
  private readonly document = inject(DOCUMENT);
  private readonly native = Capacitor.isNativePlatform();
  private readonly enabledState = signal(this.native && this.readStoredEnabled());
  private readonly availableState = signal(false);
  private readonly biometryType = signal<BiometryType>(BiometryType.NONE);
  private readonly lockedState = signal(this.enabledState());
  private readonly verifying = signal(false);
  private backgroundedAt: number | null = null;

  readonly supported = computed(() => this.native && this.availableState());
  readonly enabled = this.enabledState.asReadonly();
  readonly locked = this.lockedState.asReadonly();
  readonly busy = this.verifying.asReadonly();
  readonly label = computed(() => BIOMETRY_LABELS[this.biometryType()] ?? 'biometría');

  async start(): Promise<void> {
    if (!this.native) {
      return;
    }
    const result = await NativeBiometric.isAvailable({ useFallback: true }).catch(() => null);
    this.availableState.set(Boolean(result?.isAvailable));
    this.biometryType.set(result?.biometryType ?? BiometryType.NONE);
    if (!this.supported()) {
      this.lockedState.set(false);
      return;
    }

    await App.addListener('pause', () => (this.backgroundedAt = Date.now()));
    await App.addListener('resume', () => this.onResume());
    if (this.lockedState()) {
      await this.unlock();
    }
  }

  async unlock(): Promise<boolean> {
    if (this.verifying()) {
      return false;
    }
    this.verifying.set(true);
    try {
      await NativeBiometric.verifyIdentity({
        reason: 'Desbloquea carli',
        title: 'Desbloquear carli',
        useFallback: true,
      });
      this.lockedState.set(false);
      return true;
    } catch {
      return false;
    } finally {
      this.verifying.set(false);
    }
  }

  async setEnabled(enabled: boolean): Promise<boolean> {
    if (!this.supported()) {
      return false;
    }
    const verified = await this.unlock();
    if (!verified) {
      return false;
    }
    this.enabledState.set(enabled);
    this.store(enabled);
    return true;
  }

  private onResume(): void {
    const backgroundedAt = this.backgroundedAt;
    this.backgroundedAt = null;
    if (!this.enabledState() || backgroundedAt === null || Date.now() - backgroundedAt < BIOMETRIC_LOCK_GRACE_MS) {
      return;
    }
    this.lockedState.set(true);
    void this.unlock();
  }

  private readStoredEnabled(): boolean {
    try {
      return this.document.defaultView?.localStorage.getItem(BIOMETRIC_LOCK_STORAGE_KEY) !== 'off';
    } catch {
      return true;
    }
  }

  private store(enabled: boolean): void {
    try {
      this.document.defaultView?.localStorage.setItem(BIOMETRIC_LOCK_STORAGE_KEY, enabled ? 'on' : 'off');
    } catch {
      return;
    }
  }
}
