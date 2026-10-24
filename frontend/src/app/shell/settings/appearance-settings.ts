import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ThemePreference } from '@core/auth/auth.models';
import { ThemeService } from '@core/theme/theme.service';
import { UiCard } from '@ui/card/card';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';

@Component({
  selector: 'app-appearance-settings',
  imports: [UiCard, UiSegmented],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid-cards g-2">
      <ui-card heading="Apariencia">
        <div class="field">
          <span class="field-label" id="theme-label">Tema</span>
          <ui-segmented
            ariaLabel="Tema"
            [options]="options"
            [value]="theme.preference()"
            (valueChange)="theme.set($event!)"
          />
          <span class="field-hint">«Sistema» sigue el modo claro u oscuro de tu dispositivo.</span>
        </div>
      </ui-card>
    </div>
  `,
})
export class AppearanceSettings {
  protected readonly theme = inject(ThemeService);
  protected readonly options: UiSegmentedOption<ThemePreference>[] = [
    { value: 'light', label: 'Claro', icon: 'sun' },
    { value: 'dark', label: 'Oscuro', icon: 'moon' },
    { value: 'system', label: 'Sistema', icon: 'monitor' },
  ];
}
