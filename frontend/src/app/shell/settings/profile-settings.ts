import { ChangeDetectionStrategy, Component, effect, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { AuthService } from '@core/auth/auth.service';
import { firstValidationMessage } from '@core/http/api';
import { UiAvatar } from '@ui/avatar/avatar';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { ToastService } from '@ui/toast/toast.service';

@Component({
  selector: 'app-profile-settings',
  imports: [ReactiveFormsModule, UiCard, UiField, UiInput, UiButton, UiAvatar],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid-cards g-2">
      <ui-card heading="Perfil">
        <form class="stack" [formGroup]="form" (ngSubmit)="save()" novalidate>
          <div class="row">
            <ui-avatar [name]="form.controls.name.value || '?'" [size]="48" />
            <div>
              <div class="name">{{ auth.user()?.name }}</div>
              <div class="small faint">{{ auth.user()?.email }}</div>
            </div>
          </div>
          <ui-field label="Nombre" for="profile-name">
            <input ui-input id="profile-name" autocomplete="name" formControlName="name" />
          </ui-field>
          <ui-field label="Email" for="profile-email">
            <input ui-input id="profile-email" type="email" autocomplete="email" formControlName="email" />
          </ui-field>
          @if (error()) {
            <p class="field-error" role="alert">{{ error() }}</p>
          }
          <div class="row">
            <button ui-button type="submit" variant="primary" [loading]="saving()" [disabled]="form.pristine">
              Guardar cambios
            </button>
          </div>
        </form>
      </ui-card>
    </div>
  `,
  styles: `
    .name {
      font-weight: 600;
    }
  `,
})
export class ProfileSettings {
  protected readonly auth = inject(AuthService);
  private readonly toast = inject(ToastService);
  protected readonly form = inject(NonNullableFormBuilder).group({
    name: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
  });
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  constructor() {
    effect(() => {
      const user = this.auth.user();
      if (user && this.form.pristine) {
        this.form.reset({ name: user.name, email: user.email });
      }
    });
  }

  protected async save(): Promise<void> {
    if (this.form.invalid) {
      this.error.set('Revisa el nombre y el email.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.auth.updateProfile(this.form.getRawValue());
      this.form.markAsPristine();
      this.toast.show('Perfil actualizado');
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar el perfil.'));
    } finally {
      this.saving.set(false);
    }
  }
}
