import { NgComponentOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, input, resource } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AppModuleManifest } from '@core/modules/app-module';
import { UiIcon } from '@ui/icon/icon';
import { UiSkeleton } from '@ui/skeleton/skeleton';

@Component({
  selector: 'app-module-widget-card',
  imports: [RouterLink, NgComponentOutlet, UiIcon, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <a class="card" [routerLink]="module().basePath">
      <div class="row between">
        <div class="row">
          <span class="ico"><ui-icon [name]="module().icon" /></span>
          <h2>{{ module().name }}</h2>
        </div>
        <ui-icon name="chevron-right" class="faint" />
      </div>
      <div class="widget">
        @if (widget.value(); as component) {
          <ng-container *ngComponentOutlet="component" />
        } @else if (widget.isLoading()) {
          <ui-skeleton width="40%" height="12px" />
          <ui-skeleton width="70%" height="36px" />
        } @else if (module().description) {
          <p class="small muted">{{ module().description }}</p>
        }
      </div>
    </a>
  `,
  styles: `
    :host {
      display: block;
      min-width: 0;
    }
    .card {
      display: block;
      height: 100%;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--r-lg);
      padding: 20px;
      color: var(--text);
      text-decoration: none;
      transition: background var(--motion-fast);
    }
    .card:hover {
      background: var(--surface-2);
    }
    .card:focus-visible {
      border-radius: var(--r-lg);
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: var(--surface-2);
      flex: none;
    }
    .card:hover .ico {
      background: var(--bg);
    }
    .widget {
      margin-top: 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
  `,
})
export class AppModuleWidgetCard {
  readonly module = input.required<AppModuleManifest>();

  protected readonly widget = resource({
    params: () => this.module(),
    loader: ({ params }) => params.homeWidget?.() ?? Promise.resolve(null),
  });
}
