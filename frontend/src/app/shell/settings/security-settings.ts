import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, inject, OnInit, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { ActiveSession } from '@core/auth/auth.models';
import { AuthService } from '@core/auth/auth.service';
import { firstValidationMessage } from '@core/http/api';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiListItem } from '@ui/list-item/list-item';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { formatTimeAgo } from '../notifications/time-ago';
import { PasswordPromptData, PasswordPromptDialog } from './password-prompt-dialog';

type TwoFactorStep = 'idle' | 'setup' | 'codes';

const PASSWORD_CONFIRMATION_REQUIRED = 423;

export function describeUserAgent(userAgent: string | null): string {
  if (!userAgent) {
    return 'Dispositivo desconocido';
  }
  const browser =
    [/Edg\//, /Firefox\//, /Chrome\//, /Safari\//].map((pattern, index) =>
      pattern.test(userAgent) ? ['Edge', 'Firefox', 'Chrome', 'Safari'][index] : null,
    ).find(Boolean) ?? 'Navegador';
  const system =
    [/iPhone|iPad/, /Android/, /Mac OS X/, /Windows/, /Linux/].map((pattern, index) =>
      pattern.test(userAgent) ? ['iOS', 'Android', 'macOS', 'Windows', 'Linux'][index] : null,
    ).find(Boolean) ?? 'Sistema desconocido';
  return `${browser} · ${system}`;
}

@Component({
  selector: 'app-security-settings',
  imports: [ReactiveFormsModule, UiCard, UiField, UiInput, UiButton, UiBadge, UiListItem, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid-cards g-2">
      <ui-card heading="Contraseña">
        <form class="stack" [formGroup]="passwordForm" (ngSubmit)="changePassword()" novalidate>
          <ui-field label="Contraseña actual" for="current-password">
            <input ui-input id="current-password" type="password" autocomplete="current-password" formControlName="current_password" />
          </ui-field>
          <ui-field label="Nueva contraseña" for="new-password" hint="Mínimo 8 caracteres.">
            <input ui-input id="new-password" type="password" autocomplete="new-password" formControlName="password" />
          </ui-field>
          <ui-field label="Repite la nueva contraseña" for="confirm-password">
            <input ui-input id="confirm-password" type="password" autocomplete="new-password" formControlName="password_confirmation" />
          </ui-field>
          @if (passwordError()) {
            <p class="field-error" role="alert">{{ passwordError() }}</p>
          }
          <div class="row">
            <button ui-button type="submit" variant="primary" [loading]="savingPassword()">Cambiar contraseña</button>
          </div>
        </form>
      </ui-card>

      <ui-card heading="Verificación en dos pasos">
        <div card-actions>
          @if (auth.user()?.two_factor_enabled) {
            <ui-badge tone="positive" icon="check">Activa</ui-badge>
          } @else {
            <ui-badge>Inactiva</ui-badge>
          }
        </div>
        <div class="stack">
          <p class="small muted">Protege tu cuenta con un código de una app de autenticación (TOTP) al iniciar sesión.</p>
          @switch (twoFactorStep()) {
            @case ('setup') {
              <p class="small">Escanea este código con tu app de autenticación y escribe el código que te muestre.</p>
              @if (qrCode()) {
                <div class="qr" [innerHTML]="qrCode()"></div>
              } @else {
                <ui-skeleton width="192px" height="192px" />
              }
              @if (secretKey()) {
                <p class="small faint">Clave manual: <code class="num">{{ secretKey() }}</code></p>
              }
              <form class="stack" (ngSubmit)="confirmTwoFactor()" [formGroup]="codeForm">
                <ui-field label="Código de 6 dígitos" for="totp-code" [error]="twoFactorError()">
                  <input
                    ui-input
                    id="totp-code"
                    class="num"
                    inputmode="numeric"
                    autocomplete="one-time-code"
                    maxlength="6"
                    formControlName="code"
                    [invalid]="!!twoFactorError()"
                  />
                </ui-field>
                <div class="row">
                  <button ui-button type="submit" variant="primary" [loading]="busy()">Confirmar</button>
                  <button ui-button type="button" variant="ghost" (click)="cancelSetup()">Cancelar</button>
                </div>
              </form>
            }
            @case ('codes') {
              <p class="small">Guarda estos códigos de recuperación en un lugar seguro. Cada uno sirve una sola vez.</p>
              <ul class="codes num">
                @for (code of recoveryCodes(); track code) {
                  <li>{{ code }}</li>
                }
              </ul>
              <div class="row wrap">
                <button ui-button type="button" variant="secondary" icon="copy" (click)="copyCodes()">Copiar</button>
                <button ui-button type="button" variant="ghost" icon="refresh-cw" [loading]="busy()" (click)="regenerateCodes()">
                  Regenerar
                </button>
                <button ui-button type="button" variant="ghost" (click)="twoFactorStep.set('idle')">Hecho</button>
              </div>
            }
            @default {
              <div class="row wrap">
                @if (auth.user()?.two_factor_enabled) {
                  <button ui-button type="button" variant="secondary" icon="key-round" [loading]="busy()" (click)="showCodes()">
                    Códigos de recuperación
                  </button>
                  <button ui-button type="button" variant="ghost" (click)="disableTwoFactor()">Desactivar</button>
                } @else {
                  <button ui-button type="button" variant="primary" icon="shield-check" [loading]="busy()" (click)="startSetup()">
                    Activar
                  </button>
                }
              </div>
            }
          }
        </div>
      </ui-card>

      <ui-card heading="Sesiones activas">
        <button card-actions ui-button type="button" variant="ghost" size="sm" (click)="logoutOthers()">
          Cerrar las demás
        </button>
        @if (sessionsLoading()) {
          <ui-skeleton height="56px" />
        } @else {
          @for (session of sessions(); track session.id) {
            <ui-list-item
              [heading]="session.device"
              [subtitle]="(session.ip_address ?? 'IP desconocida') + ' · ' + timeAgo(session.last_active_at)"
              [icon]="session.is_mobile ? 'smartphone' : 'laptop'"
            >
              @if (session.is_current) {
                <ui-badge trailing tone="primary">Este dispositivo</ui-badge>
              }
            </ui-list-item>
          } @empty {
            <p class="small faint">No hay información de sesiones.</p>
          }
        }
      </ui-card>
    </div>
  `,
  styles: `
    .qr {
      width: 192px;
      height: 192px;
      padding: 8px;
      background: #fff;
      border-radius: var(--r-md);
    }
    .qr ::ng-deep svg {
      width: 100%;
      height: 100%;
    }
    .codes {
      list-style: none;
      margin: 0;
      padding: 12px 16px;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 6px 16px;
      background: var(--surface-2);
      border-radius: var(--r-md);
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 13px;
    }
    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      color: var(--text);
    }
  `,
})
export class SecuritySettings implements OnInit {
  protected readonly auth = inject(AuthService);
  private readonly dialogs = inject(DialogService);
  private readonly toast = inject(ToastService);
  private readonly sanitizer = inject(DomSanitizer);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly passwordForm = this.fb.group({
    current_password: ['', Validators.required],
    password: ['', [Validators.required, Validators.minLength(8)]],
    password_confirmation: ['', Validators.required],
  });
  protected readonly codeForm = this.fb.group({ code: ['', Validators.required] });

  protected readonly savingPassword = signal(false);
  protected readonly passwordError = signal<string | null>(null);
  protected readonly twoFactorStep = signal<TwoFactorStep>('idle');
  protected readonly twoFactorError = signal<string | null>(null);
  protected readonly busy = signal(false);
  protected readonly qrCode = signal<SafeHtml | null>(null);
  protected readonly secretKey = signal<string | null>(null);
  protected readonly recoveryCodes = signal<string[]>([]);
  protected readonly sessions = signal<ActiveSession[]>([]);
  protected readonly sessionsLoading = signal(true);

  ngOnInit(): void {
    void this.loadSessions();
  }

  protected timeAgo(value: string): string {
    return formatTimeAgo(value);
  }

  protected async changePassword(): Promise<void> {
    const value = this.passwordForm.getRawValue();
    if (this.passwordForm.invalid) {
      this.passwordError.set('Rellena los tres campos; la nueva contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (value.password !== value.password_confirmation) {
      this.passwordError.set('Las contraseñas nuevas no coinciden.');
      return;
    }
    this.savingPassword.set(true);
    this.passwordError.set(null);
    try {
      await this.auth.updatePassword(value);
      this.passwordForm.reset();
      this.toast.show('Contraseña actualizada');
    } catch (error) {
      this.passwordError.set(firstValidationMessage(error, 'No se ha podido cambiar la contraseña.'));
    } finally {
      this.savingPassword.set(false);
    }
  }

  protected async startSetup(): Promise<void> {
    await this.withBusy(async () => {
      const enabled = await this.withPasswordConfirmation(() => this.auth.enableTwoFactor());
      if (!enabled) {
        return;
      }
      this.twoFactorStep.set('setup');
      const [qr, secret] = await Promise.all([this.auth.twoFactorQrCode(), this.auth.twoFactorSecretKey().catch(() => null)]);
      this.qrCode.set(this.sanitizer.bypassSecurityTrustHtml(qr.svg));
      this.secretKey.set(secret);
    });
  }

  protected async confirmTwoFactor(): Promise<void> {
    const code = this.codeForm.getRawValue().code.trim();
    if (!code) {
      this.twoFactorError.set('Introduce el código.');
      return;
    }
    await this.withBusy(async () => {
      try {
        await this.auth.confirmTwoFactor(code);
        this.twoFactorError.set(null);
        this.codeForm.reset();
        this.recoveryCodes.set(await this.auth.recoveryCodes());
        this.twoFactorStep.set('codes');
        this.toast.show('Verificación en dos pasos activada');
      } catch (error) {
        this.twoFactorError.set(firstValidationMessage(error, 'El código no es válido.'));
      }
    });
  }

  protected async cancelSetup(): Promise<void> {
    this.twoFactorStep.set('idle');
    this.qrCode.set(null);
    await this.auth.disableTwoFactor().catch(() => undefined);
  }

  protected async showCodes(): Promise<void> {
    await this.withBusy(async () => {
      const loaded = await this.withPasswordConfirmation(async () => this.recoveryCodes.set(await this.auth.recoveryCodes()));
      if (loaded) {
        this.twoFactorStep.set('codes');
      }
    });
  }

  protected async regenerateCodes(): Promise<void> {
    await this.withBusy(async () => {
      await this.withPasswordConfirmation(async () => this.recoveryCodes.set(await this.auth.regenerateRecoveryCodes()));
    });
  }

  protected async copyCodes(): Promise<void> {
    await navigator.clipboard?.writeText(this.recoveryCodes().join('\n'));
    this.toast.show('Códigos copiados');
  }

  protected async disableTwoFactor(): Promise<void> {
    const confirmed = await this.dialogs.confirm({
      title: 'Desactivar la verificación en dos pasos',
      message: 'Tu cuenta quedará protegida solo con la contraseña.',
      confirmLabel: 'Desactivar',
      danger: true,
    });
    if (!confirmed) {
      return;
    }
    await this.withBusy(async () => {
      const disabled = await this.withPasswordConfirmation(() => this.auth.disableTwoFactor());
      if (disabled) {
        this.toast.show('Verificación en dos pasos desactivada');
      }
    });
  }

  protected async logoutOthers(): Promise<void> {
    const password = await this.promptPassword({
      title: 'Cerrar las demás sesiones',
      message: 'Se cerrará la sesión en todos tus otros dispositivos. Confirma con tu contraseña.',
      confirmLabel: 'Cerrar sesiones',
    });
    if (!password) {
      return;
    }
    try {
      await this.auth.logoutOtherSessions(password);
      this.toast.show('Sesiones cerradas en los demás dispositivos');
      await this.loadSessions();
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se han podido cerrar las sesiones.'));
    }
  }

  private async loadSessions(): Promise<void> {
    this.sessionsLoading.set(true);
    try {
      this.sessions.set(await this.auth.sessions());
    } catch {
      this.sessions.set([]);
    } finally {
      this.sessionsLoading.set(false);
    }
  }

  private async withBusy(action: () => Promise<void>): Promise<void> {
    this.busy.set(true);
    try {
      await action();
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'Algo ha fallado. Inténtalo de nuevo.'));
    } finally {
      this.busy.set(false);
    }
  }

  private async withPasswordConfirmation(action: () => Promise<unknown>): Promise<boolean> {
    try {
      await action();
      return true;
    } catch (error) {
      if (!(error instanceof HttpErrorResponse) || error.status !== PASSWORD_CONFIRMATION_REQUIRED) {
        throw error;
      }
    }
    const password = await this.promptPassword({
      title: 'Confirma tu contraseña',
      message: 'Por seguridad, vuelve a introducir tu contraseña para continuar.',
      confirmLabel: 'Confirmar',
    });
    if (!password) {
      return false;
    }
    await this.auth.confirmPassword(password);
    await action();
    return true;
  }

  private async promptPassword(data: PasswordPromptData): Promise<string | undefined> {
    const ref = this.dialogs.open<PasswordPromptDialog, PasswordPromptData, string>(PasswordPromptDialog, { data });
    return firstValueFrom(ref.closed);
  }
}
