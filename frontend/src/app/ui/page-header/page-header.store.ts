import { Portal } from '@angular/cdk/portal';
import { Injectable, signal } from '@angular/core';

export interface PageHeaderState {
  heading: string;
  crumb: string | null;
  actions: Portal<unknown> | null;
  backLink: string | null;
}

const EMPTY_HEADER: PageHeaderState = { heading: '', crumb: null, actions: null, backLink: null };

@Injectable({ providedIn: 'root' })
export class PageHeaderStore {
  private readonly current = signal<PageHeaderState>(EMPTY_HEADER);
  private owner: object | null = null;

  readonly state = this.current.asReadonly();

  set(owner: object, state: PageHeaderState): void {
    this.owner = owner;
    this.current.set(state);
  }

  clear(owner: object): void {
    if (this.owner === owner) {
      this.owner = null;
      this.current.set(EMPTY_HEADER);
    }
  }
}
