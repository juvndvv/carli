import { DOCUMENT } from '@angular/common';
import { inject, Injectable } from '@angular/core';
import { NavigationCancel, NavigationEnd, NavigationError, Router } from '@angular/router';
import { BiometricLockService } from '@core/biometric/biometric-lock.service';
import { filter, firstValueFrom } from 'rxjs';

const ANIMATION_MS = 1500;
const FADE_FALLBACK_MS = 400;

@Injectable({ providedIn: 'root' })
export class LaunchScreen {
  private readonly document = inject(DOCUMENT);
  private readonly router = inject(Router);
  private readonly biometricLock = inject(BiometricLockService);
  private readonly element = this.document.getElementById('launch');
  private dismissed = false;

  constructor() {
    this.element?.addEventListener('click', () => this.hide(), { once: true });
  }

  async dismissAfterStartup(startup: Promise<unknown>): Promise<void> {
    if (!this.element) return;
    const firstNavigation = firstValueFrom(
      this.router.events.pipe(
        filter((event) => event instanceof NavigationEnd || event instanceof NavigationCancel || event instanceof NavigationError),
      ),
    );
    await Promise.all([firstNavigation, startup.catch(() => undefined)]);
    if (this.biometricLock.locked() || !this.shouldAnimate()) {
      this.hide();
      return;
    }
    this.element.classList.add('launch-animated');
    setTimeout(() => this.hide(), ANIMATION_MS);
  }

  private shouldAnimate(): boolean {
    const installed = this.element?.dataset['installed'] !== undefined;
    const reducedMotion = this.document.defaultView?.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
    return installed && !reducedMotion;
  }

  private hide(): void {
    const element = this.element;
    if (this.dismissed || !element) return;
    this.dismissed = true;
    const remove = () => element.remove();
    element.addEventListener('transitionend', remove, { once: true });
    setTimeout(remove, FADE_FALLBACK_MS);
    element.classList.add('launch-out');
  }
}
