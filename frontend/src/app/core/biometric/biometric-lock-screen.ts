import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { UiButton } from '@ui/button/button';
import { UiIcon } from '@ui/icon/icon';
import { BiometricLockService } from './biometric-lock.service';

@Component({
  selector: 'app-biometric-lock-screen',
  imports: [UiButton, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'lock-title' },
  template: `
    <div class="content stack">
      <span class="mark"><ui-icon name="scan-face" [size]="40" /></span>
      <h1 id="lock-title" class="title">Personal está bloqueada</h1>
      <p class="small muted">Usa {{ lock.label() }} para continuar.</p>
      <button ui-button type="button" variant="primary" size="lg" icon="scan-face" [loading]="lock.busy()" (click)="lock.unlock()">
        Desbloquear
      </button>
    </div>
  `,
  styles: `
    :host {
      position: fixed;
      inset: 0;
      z-index: 1000;
      display: grid;
      place-items: center;
      padding: 16px;
      background: var(--bg);
    }
    .content {
      align-items: center;
      text-align: center;
      max-width: 320px;
    }
    .mark {
      width: 72px;
      height: 72px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: var(--primary);
      color: var(--on-primary);
    }
    .title {
      margin: 0;
      font-size: 20px;
      font-weight: 600;
    }
  `,
})
export class BiometricLockScreen {
  protected readonly lock = inject(BiometricLockService);
}
