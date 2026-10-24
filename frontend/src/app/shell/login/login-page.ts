import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '@core/auth/auth.service';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiLogo } from '@ui/logo/logo';

type LoginStep = 'credentials' | 'two_factor';

@Component({
  selector: 'app-login-page',
  imports: [ReactiveFormsModule, UiButton, UiField, UiInput, UiLogo],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <main class="login">
      <section class="panel stack" aria-labelledby="login-title">
        <div class="row">
          <ui-logo [size]="36" />
          <div>
            <h1 id="login-title" class="brand-name">carli</h1>
            <div class="small faint">Tu asistente personal</div>
          </div>
        </div>

        @if (step() === 'credentials') {
          <form class="stack" [formGroup]="credentials" (ngSubmit)="submitCredentials()" novalidate>
            <ui-field label="Email" for="login-email">
              <input
                ui-input
                id="login-email"
                type="email"
                autocomplete="username"
                inputmode="email"
                formControlName="email"
                [invalid]="!!error()"
              />
            </ui-field>
            <ui-field label="Contraseña" for="login-password">
              <input
                ui-input
                id="login-password"
                type="password"
                autocomplete="current-password"
                formControlName="password"
                [invalid]="!!error()"
              />
            </ui-field>
            <label class="row small muted remember">
              <input type="checkbox" formControlName="remember" />
              Mantener la sesión iniciada
            </label>
            @if (error()) {
              <p class="field-error" role="alert">{{ error() }}</p>
            }
            <button ui-button type="submit" variant="primary" size="lg" block [loading]="busy()">Entrar</button>
          </form>
        } @else {
          <form class="stack" [formGroup]="challenge" (ngSubmit)="submitChallenge()" novalidate>
            <div>
              <h2>Verificación en dos pasos</h2>
              <p class="small muted">
                @if (useRecovery()) {
                  Introduce uno de tus códigos de recuperación.
                } @else {
                  Introduce el código de 6 dígitos de tu app de autenticación.
                }
              </p>
            </div>
            @if (useRecovery()) {
              <ui-field label="Código de recuperación" for="login-recovery">
                <input ui-input id="login-recovery" autocomplete="off" formControlName="recovery_code" [invalid]="!!error()" />
              </ui-field>
            } @else {
              <ui-field label="Código" for="login-code">
                <input
                  ui-input
                  id="login-code"
                  class="num code"
                  inputmode="numeric"
                  autocomplete="one-time-code"
                  maxlength="6"
                  formControlName="code"
                  [invalid]="!!error()"
                />
              </ui-field>
            }
            @if (error()) {
              <p class="field-error" role="alert">{{ error() }}</p>
            }
            <button ui-button type="submit" variant="primary" size="lg" block [loading]="busy()">Verificar</button>
            <div class="row between small">
              <button type="button" class="link" (click)="toggleRecovery()">
                {{ useRecovery() ? 'Usar código de la app' : 'Usar un código de recuperación' }}
              </button>
              <button type="button" class="link" (click)="backToCredentials()">Volver</button>
            </div>
          </form>
        }
        <div class="small faint footnote">Acceso privado · sin registro público</div>
      </section>
    </main>
  `,
  styles: `
    .login {
      min-height: 100vh;
      min-height: 100dvh;
      display: grid;
      place-items: center;
      padding: 16px;
    }
    .panel {
      width: 100%;
      max-width: 380px;
      padding: 28px;
      background: var(--surface);
      border-radius: var(--r-lg);
    }
    .brand-name {
      font-size: 20px;
      line-height: 24px;
      font-weight: 650;
      letter-spacing: -0.03em;
    }
    .remember {
      gap: 8px;
    }
    .remember input {
      width: 16px;
      height: 16px;
      accent-color: var(--primary);
    }
    .code {
      letter-spacing: 0.3em;
      font-size: 20px;
      text-align: center;
    }
    .link {
      background: none;
      border: 0;
      padding: 0;
      color: var(--text-2);
      text-decoration: underline;
      text-decoration-color: var(--border);
      text-underline-offset: 3px;
    }
    .footnote {
      text-align: center;
    }
  `,
})
export class LoginPage {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly step = signal<LoginStep>('credentials');
  protected readonly busy = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly useRecovery = signal(false);

  protected readonly credentials = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required],
    remember: [true],
  });

  protected readonly challenge = this.fb.group({
    code: [''],
    recovery_code: [''],
  });

  protected async submitCredentials(): Promise<void> {
    if (this.credentials.invalid) {
      this.credentials.markAllAsTouched();
      this.error.set('Introduce tu email y tu contraseña.');
      return;
    }
    await this.run(async () => {
      const result = await this.auth.login(this.credentials.getRawValue());
      if (result === 'two_factor') {
        this.step.set('two_factor');
        return;
      }
      await this.redirect();
    }, 'Email o contraseña incorrectos.');
  }

  protected async submitChallenge(): Promise<void> {
    const { code, recovery_code } = this.challenge.getRawValue();
    const answer = this.useRecovery() ? { recovery_code: recovery_code.trim() } : { code: code.trim() };
    if (Object.values(answer)[0] === '') {
      this.error.set('Introduce el código.');
      return;
    }
    await this.run(async () => {
      await this.auth.completeTwoFactor(answer);
      await this.redirect();
    }, 'El código no es válido.');
  }

  protected toggleRecovery(): void {
    this.useRecovery.update((value) => !value);
    this.error.set(null);
  }

  protected backToCredentials(): void {
    this.step.set('credentials');
    this.challenge.reset();
    this.error.set(null);
  }

  private async run(action: () => Promise<void>, fallback: string): Promise<void> {
    this.busy.set(true);
    this.error.set(null);
    try {
      await action();
    } catch (error) {
      this.error.set(this.messageFor(error, fallback));
    } finally {
      this.busy.set(false);
    }
  }

  private messageFor(error: unknown, fallback: string): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 429) {
        return 'Demasiados intentos. Espera un minuto y vuelve a probar.';
      }
      if (error.status === 0) {
        return 'No se puede conectar con el servidor.';
      }
      if (error.status === 422) {
        return firstValidationMessage(error, fallback);
      }
    }
    return fallback;
  }

  private async redirect(): Promise<void> {
    const target = this.route.snapshot.queryParamMap.get('redirect');
    const safeTarget = target && target.startsWith('/') && !target.startsWith('//') ? target : '/';
    await this.router.navigateByUrl(safeTarget);
  }
}
