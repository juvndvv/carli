import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { AppModuleId, ModuleRegistry } from '@core/modules/app-module';
import { UiBadge } from '@ui/badge/badge';
import { UiCard } from '@ui/card/card';
import { UiIcon } from '@ui/icon/icon';
import { UiSwitch } from '@ui/switch/switch';
import { ToastService } from '@ui/toast/toast.service';

@Component({
  selector: 'app-module-settings',
  imports: [UiCard, UiSwitch, UiBadge, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid-cards g-2">
      <ui-card heading="Módulos">
        <p class="small muted intro">Un módulo desactivado desaparece de la navegación. Tus datos se conservan.</p>
        <div class="stack">
          @for (module of registry.manifests; track module.id) {
            <div class="row between">
              <span class="row"><ui-icon [name]="module.icon" />{{ module.name }}</span>
              <ui-switch
                [label]="'Activar ' + module.name"
                [checked]="registry.isEnabled(module.id)"
                [disabled]="pending() === module.id"
                (checkedChange)="toggle(module.id, $event)"
              />
            </div>
          }
          @for (module of registry.upcoming(); track module.id) {
            <div class="row between">
              <span class="row faint"><ui-icon [name]="module.icon" />{{ module.name }}</span>
              <ui-badge>Próximamente</ui-badge>
            </div>
          }
        </div>
      </ui-card>
    </div>
  `,
  styles: `
    .intro {
      margin-bottom: 16px;
    }
  `,
})
export class ModuleSettings {
  protected readonly registry = inject(ModuleRegistry);
  private readonly toast = inject(ToastService);
  protected readonly pending = signal<AppModuleId | null>(null);

  protected async toggle(id: AppModuleId, enabled: boolean): Promise<void> {
    this.pending.set(id);
    try {
      await this.registry.setEnabled(id, enabled);
    } catch {
      this.toast.error('No se ha podido cambiar el módulo');
    } finally {
      this.pending.set(null);
    }
  }
}
