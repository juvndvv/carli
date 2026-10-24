import { NgComponentOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject, input, resource } from '@angular/core';
import { AppModuleId, ModuleRegistry } from '@core/modules/app-module';
import { UiCard } from '@ui/card/card';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiSkeleton } from '@ui/skeleton/skeleton';

@Component({
  selector: 'app-module-settings-host',
  imports: [NgComponentOutlet, UiCard, UiEmptyState, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (component.value(); as settings) {
      <ng-container *ngComponentOutlet="settings" />
    } @else if (component.isLoading()) {
      <ui-skeleton height="160px" radius="var(--r-lg)" />
    } @else {
      <ui-card>
        <ui-empty-state icon="settings" heading="Sin ajustes" description="Este módulo no tiene ajustes propios." />
      </ui-card>
    }
  `,
})
export class ModuleSettingsHost {
  private readonly registry = inject(ModuleRegistry);

  readonly moduleId = input.required<string>();

  private readonly manifest = computed(() => this.registry.manifest(this.moduleId() as AppModuleId));
  protected readonly component = resource({
    params: () => this.manifest(),
    loader: ({ params }) => params.settings?.() ?? Promise.resolve(null),
  });
}
