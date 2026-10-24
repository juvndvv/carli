import { TemplatePortal } from '@angular/cdk/portal';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  effect,
  inject,
  input,
  TemplateRef,
  viewChild,
  ViewContainerRef,
} from '@angular/core';
import { Title } from '@angular/platform-browser';
import { PageHeaderStore } from './page-header.store';

export const APP_TITLE = 'Personal App';

@Component({
  selector: 'ui-page-header',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<ng-template #actions><ng-content /></ng-template>`,
  styles: `
    :host {
      display: none;
    }
  `,
})
export class UiPageHeader {
  private readonly store = inject(PageHeaderStore);
  private readonly title = inject(Title);
  private readonly viewContainerRef = inject(ViewContainerRef);
  private readonly actions = viewChild.required<TemplateRef<unknown>>('actions');

  readonly heading = input.required<string>();
  readonly crumb = input<string | null>(null);
  readonly backLink = input<string | null>(null);

  constructor() {
    effect(() => {
      const heading = this.heading();
      this.store.set(this, {
        heading,
        crumb: this.crumb(),
        backLink: this.backLink(),
        actions: new TemplatePortal(this.actions(), this.viewContainerRef),
      });
      this.title.setTitle(heading ? `${heading} · ${APP_TITLE}` : APP_TITLE);
    });
    inject(DestroyRef).onDestroy(() => this.store.clear(this));
  }
}
