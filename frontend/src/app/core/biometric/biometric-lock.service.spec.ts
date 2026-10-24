import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { BiometryType } from '@capgo/capacitor-native-biometric';
import { BIOMETRIC_LOCK_GRACE_MS, BIOMETRIC_LOCK_STORAGE_KEY, BiometricLockService } from './biometric-lock.service';

const platform = vi.hoisted(() => ({ native: true }));
const listeners = vi.hoisted(() => new Map<string, () => void>());
const biometric = vi.hoisted(() => ({
  isAvailable: vi.fn(),
  verifyIdentity: vi.fn(),
}));

vi.mock('@capacitor/core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@capacitor/core')>()),
  Capacitor: { isNativePlatform: () => platform.native },
}));
vi.mock('@capacitor/app', () => ({
  App: {
    addListener: (event: string, listener: () => void) => {
      listeners.set(event, listener);
      return Promise.resolve({ remove: () => Promise.resolve() });
    },
  },
}));
vi.mock('@capgo/capacitor-native-biometric', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@capgo/capacitor-native-biometric')>()),
  NativeBiometric: biometric,
}));

describe('BiometricLockService', () => {
  function setup(): BiometricLockService {
    TestBed.configureTestingModule({ providers: [provideZonelessChangeDetection()] });
    return TestBed.inject(BiometricLockService);
  }

  beforeEach(() => {
    localStorage.clear();
    listeners.clear();
    platform.native = true;
    biometric.isAvailable.mockResolvedValue({ isAvailable: true, biometryType: BiometryType.FACE_ID });
    biometric.verifyIdentity.mockResolvedValue(undefined);
  });

  afterEach(() => vi.useRealTimers());

  it('never locks on the web', async () => {
    platform.native = false;
    const lock = setup();

    await lock.start();

    expect(lock.locked()).toBe(false);
    expect(lock.supported()).toBe(false);
    expect(biometric.isAvailable).not.toHaveBeenCalled();
  });

  it('starts locked and unlocks after Face ID succeeds', async () => {
    const lock = setup();
    expect(lock.locked()).toBe(true);

    await lock.start();

    expect(lock.locked()).toBe(false);
    expect(lock.label()).toBe('Face ID');
  });

  it('stays locked when verification is cancelled', async () => {
    biometric.verifyIdentity.mockRejectedValue(new Error('cancelled'));
    const lock = setup();

    await lock.start();

    expect(lock.locked()).toBe(true);
  });

  it('unlocks without prompting when the device has no biometrics', async () => {
    biometric.isAvailable.mockResolvedValue({ isAvailable: false, biometryType: BiometryType.NONE });
    const lock = setup();

    await lock.start();

    expect(lock.locked()).toBe(false);
    expect(biometric.verifyIdentity).not.toHaveBeenCalled();
  });

  it('locks again only after the grace period in the background', async () => {
    vi.useFakeTimers({ now: 0 });
    const lock = setup();
    await lock.start();
    biometric.verifyIdentity.mockReturnValue(new Promise(() => undefined));

    listeners.get('pause')?.();
    vi.setSystemTime(BIOMETRIC_LOCK_GRACE_MS - 1);
    listeners.get('resume')?.();
    expect(lock.locked()).toBe(false);

    listeners.get('pause')?.();
    vi.setSystemTime(2 * BIOMETRIC_LOCK_GRACE_MS);
    listeners.get('resume')?.();
    expect(lock.locked()).toBe(true);
  });

  it('remembers when the lock is turned off', async () => {
    const lock = setup();
    await lock.start();

    expect(await lock.setEnabled(false)).toBe(true);

    expect(lock.enabled()).toBe(false);
    expect(localStorage.getItem(BIOMETRIC_LOCK_STORAGE_KEY)).toBe('off');
  });
});
