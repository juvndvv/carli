import { DOCUMENT } from '@angular/common';
import { inject, Injectable } from '@angular/core';
import { NavigationCancel, NavigationEnd, NavigationError, Router } from '@angular/router';
import { filter, take } from 'rxjs';

const ANIMATION_MS = 1700;
const FADE_FALLBACK_MS = 400;

@Injectable({ providedIn: 'root' })
export class LaunchScreen {
  private readonly document = inject(DOCUMENT);
  private readonly router = inject(Router);
  private readonly element = this.document.getElementById('launch');
  private dismissed = false;

  constructor() {
    this.element?.addEventListener('click', () => this.hide(), { once: true });
  }

  dismissAfterFirstNavigation(): void {
    this.router.events
      .pipe(
        filter((event) => event instanceof NavigationEnd || event instanceof NavigationCancel || event instanceof NavigationError),
        take(1),
      )
      .subscribe(() => requestAnimationFrame(() => this.dismiss()));
  }

  private dismiss(): void {
    if (!this.element) return;
    const animated = this.element.classList.contains('launch-animated') && !this.prefersReducedMotion();
    const startedAt = Number(this.element.dataset['startedAt'] ?? 0);
    const remaining = animated ? Math.max(0, startedAt + ANIMATION_MS - performance.now()) : 0;
    setTimeout(() => this.hide(), remaining);
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

  private prefersReducedMotion(): boolean {
    return this.document.defaultView?.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
  }
}
