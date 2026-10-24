import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from '@core/theme/theme.service';
import { UiToastHost } from '@ui/toast/toast-host';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, UiToastHost],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <router-outlet />
    <ui-toast-host />
  `,
})
export class App {
  constructor() {
    inject(ThemeService);
  }
}
