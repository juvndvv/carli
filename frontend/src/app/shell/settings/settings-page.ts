import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ModuleRegistry } from '@core/modules/app-module';
import { UiPageHeader } from '@ui/page-header/page-header';
import { UiTab, UiTabs } from '@ui/tabs/tabs';

@Component({
  selector: 'app-settings-page',
  imports: [UiPageHeader, UiTabs, RouterOutlet],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Ajustes" crumb="Cuenta" />
    <ui-tabs [tabs]="tabs()" ariaLabel="Secciones de ajustes" />
    <router-outlet />
  `,
})
export class SettingsPage {
  private readonly registry = inject(ModuleRegistry);

  protected readonly tabs = computed<UiTab[]>(() => [
    { id: 'perfil', label: 'Perfil', link: '/ajustes/perfil' },
    { id: 'seguridad', label: 'Seguridad', link: '/ajustes/seguridad' },
    { id: 'apariencia', label: 'Apariencia', link: '/ajustes/apariencia' },
    { id: 'notificaciones', label: 'Notificaciones', link: '/ajustes/notificaciones' },
    { id: 'modulos', label: 'Módulos', link: '/ajustes/modulos' },
    ...this.registry
      .enabled()
      .filter((module) => !!module.settings)
      .map((module) => ({ id: module.id, label: module.name, link: `/ajustes/modulo/${module.id}` })),
  ]);
}
