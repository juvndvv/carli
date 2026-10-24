import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { UiButton } from '../button/button';
import { UiDialog } from './dialog';

export interface UiConfirmDialogData {
  title: string;
  message?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
}

@Component({
  selector: 'ui-confirm-dialog',
  imports: [UiDialog, UiButton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="data.title">
      @if (data.message) {
        <p class="muted">{{ data.message }}</p>
      }
      <div dialog-footer class="footer">
        <button ui-button type="button" variant="ghost" (click)="ref.close(false)">
          {{ data.cancelLabel ?? 'Cancelar' }}
        </button>
        <button ui-button type="button" [variant]="data.danger ? 'danger' : 'primary'" (click)="ref.close(true)">
          {{ data.confirmLabel ?? 'Confirmar' }}
        </button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .footer {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
  `,
})
export class UiConfirmDialog {
  protected readonly data = inject<UiConfirmDialogData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
}
