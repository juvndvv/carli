import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '@core/auth/auth.service';
import { ModuleRegistry } from '@core/modules/app-module';
import { UiCard } from '@ui/card/card';
import { UiIcon } from '@ui/icon/icon';
import { UiListItem } from '@ui/list-item/list-item';
import { UiPageHeader } from '@ui/page-header/page-header';

@Component({
  selector: 'app-more-page',
  imports: [UiPageHeader, UiCard, UiListItem, UiIcon, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Más" crumb="Secciones" />
    <div class="stack">
      @for (group of groups(); track group.id) {
        <ui-card padding="list" [heading]="group.name">
          @for (item of group.items; track item.path) {
            <a ui-list-item [routerLink]="item.path" [heading]="item.label" [icon]="item.icon" iconSoft>
              <ui-icon trailing name="chevron-right" class="faint" />
            </a>
          }
        </ui-card>
      }
      <ui-card padding="list" heading="Cuenta">
        <a ui-list-item routerLink="/notificaciones" heading="Notificaciones" icon="bell" iconSoft>
          <ui-icon trailing name="chevron-right" class="faint" />
        </a>
        <a ui-list-item routerLink="/ajustes" heading="Ajustes" icon="settings" iconSoft>
          <ui-icon trailing name="chevron-right" class="faint" />
        </a>
        <a ui-list-item routerLink="/dev/ui" heading="Design system" icon="palette" iconSoft>
          <ui-icon trailing name="chevron-right" class="faint" />
        </a>
        <button ui-list-item type="button" heading="Cerrar sesión" icon="log-out" iconSoft (click)="logout()"></button>
      </ui-card>
    </div>
  `,
})
export class MorePage {
  private readonly registry = inject(ModuleRegistry);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  protected readonly groups = computed(() =>
    this.registry
      .enabled()
      .map((module) => ({ id: module.id, name: module.name, items: module.nav.filter((item) => !item.primary) }))
      .filter((group) => group.items.length > 0),
  );

  protected async logout(): Promise<void> {
    await this.auth.logout();
    await this.router.navigateByUrl('/login');
  }
}
