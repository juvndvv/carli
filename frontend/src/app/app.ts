import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { BiometricLockScreen } from '@core/biometric/biometric-lock-screen';
import { BiometricLockService } from '@core/biometric/biometric-lock.service';
import { ThemeService } from '@core/theme/theme.service';
import { UiToastHost } from '@ui/toast/toast-host';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, UiToastHost, BiometricLockScreen],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <router-outlet />
    <ui-toast-host />
    @if (biometricLock.locked()) {
      <app-biometric-lock-screen />
    }
  `,
})
export class App {
  protected readonly biometricLock = inject(BiometricLockService);

  constructor() {
    inject(ThemeService);
    void this.biometricLock.start();
  }
}
