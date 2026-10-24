import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';

export interface PasswordPromptData {
  title: string;
  message: string;
  confirmLabel: string;
}

@Component({
  selector: 'app-password-prompt-dialog',
  imports: [FormsModule, UiDialog, UiButton, UiField, UiInput],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="data.title">
      <form class="stack" (ngSubmit)="submit()">
        <p class="small muted">{{ data.message }}</p>
        <ui-field label="Contraseña" for="password-prompt">
          <input
            ui-input
            id="password-prompt"
            type="password"
            name="password"
            autocomplete="current-password"
            [ngModel]="password()"
            (ngModelChange)="password.set($event)"
          />
        </ui-field>
        <div class="footer">
          <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
          <button ui-button type="submit" variant="primary" [disabled]="!password()">{{ data.confirmLabel }}</button>
        </div>
      </form>
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
export class PasswordPromptDialog {
  protected readonly data = inject<PasswordPromptData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<string>>(DialogRef);
  protected readonly password = signal('');

  protected submit(): void {
    if (this.password()) {
      this.ref.close(this.password());
    }
  }
}
