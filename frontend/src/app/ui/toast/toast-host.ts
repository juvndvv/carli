import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { UiIcon } from '../icon/icon';
import { ToastService } from './toast.service';

@Component({
  selector: 'ui-toast-host',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { 'aria-live': 'polite', 'aria-atomic': 'true' },
  template: `
    @for (toast of toasts.active(); track toast.id) {
      <div class="toast" role="status" [class.error]="toast.tone === 'error'">
        @if (toast.tone === 'error') {
          <ui-icon name="circle-alert" [size]="16" />
        }
        <span class="message">{{ toast.message }}</span>
        @if (toast.action) {
          <button type="button" class="action" (click)="toasts.runAction(toast.id)">{{ toast.action.label }}</button>
        }
        <button type="button" class="close" aria-label="Cerrar aviso" (click)="toasts.dismiss(toast.id)">
          <ui-icon name="x" [size]="16" />
        </button>
      </div>
    }
  `,
  styles: `
    :host {
      position: fixed;
      left: 50%;
      bottom: 24px;
      transform: translateX(-50%);
      z-index: 1100;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      pointer-events: none;
      width: max-content;
      max-width: calc(100vw - 32px);
    }
    @media (max-width: 1023px) {
      :host {
        bottom: calc(150px + env(safe-area-inset-bottom));
      }
    }
    .toast {
      pointer-events: auto;
      display: flex;
      align-items: center;
      gap: 16px;
      background: var(--text);
      color: var(--bg);
      padding: 10px 10px 10px 18px;
      border-radius: var(--r-full);
      box-shadow: var(--shadow-2);
      animation: ui-toast-in var(--motion-enter) ease-out;
    }
    .toast.error {
      gap: 10px;
    }
    .message {
      min-width: 0;
    }
    .action {
      background: none;
      border: 0;
      color: var(--bg);
      text-decoration: underline;
      font-weight: 600;
      padding: 0;
    }
    .close {
      width: 28px;
      height: 28px;
      border: 0;
      border-radius: 999px;
      background: none;
      color: var(--bg);
      opacity: 0.7;
      display: grid;
      place-items: center;
    }
    .close:hover {
      opacity: 1;
    }
    @keyframes ui-toast-in {
      from {
        transform: translateY(8px);
        opacity: 0;
      }
    }
  `,
})
export class UiToastHost {
  protected readonly toasts = inject(ToastService);
}
