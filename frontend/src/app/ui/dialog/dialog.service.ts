import { Dialog, DialogConfig, DialogRef } from '@angular/cdk/dialog';
import { BreakpointObserver } from '@angular/cdk/layout';
import { createGlobalPositionStrategy } from '@angular/cdk/overlay';
import { ComponentType } from '@angular/cdk/portal';
import { inject, Injectable, Injector } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { UiConfirmDialog, UiConfirmDialogData } from './confirm-dialog';
import { MOBILE_SHEET_QUERY, SHEET_PANEL_CLASS } from './dialog-tokens';

export type DialogPresentation = 'auto' | 'dialog' | 'sheet';
export type DialogSize = 'md' | 'lg';

export interface UiDialogOptions<D> {
  data?: D;
  presentation?: DialogPresentation;
  size?: DialogSize;
  disableClose?: boolean;
  ariaLabel?: string;
  injector?: Injector;
}


@Injectable({ providedIn: 'root' })
export class DialogService {
  private readonly dialog = inject(Dialog);
  private readonly injector = inject(Injector);
  private readonly breakpoints = inject(BreakpointObserver);

  open<C, D = unknown, R = unknown>(component: ComponentType<C>, options: UiDialogOptions<D> = {}): DialogRef<R, C> {
    const presentation = options.presentation ?? 'auto';
    const asSheet =
      presentation === 'sheet' || (presentation === 'auto' && this.breakpoints.isMatched(MOBILE_SHEET_QUERY));
    const positionStrategy = asSheet
      ? createGlobalPositionStrategy(this.injector).centerHorizontally().bottom('0')
      : createGlobalPositionStrategy(this.injector).centerHorizontally().centerVertically();
    const config: DialogConfig<D, DialogRef<R, C>> = {
      data: options.data,
      disableClose: options.disableClose ?? false,
      ariaLabel: options.ariaLabel ?? null,
      autoFocus: 'dialog',
      restoreFocus: true,
      hasBackdrop: true,
      backdropClass: ['cdk-overlay-dark-backdrop', 'ui-scrim'],
      panelClass: asSheet ? [SHEET_PANEL_CLASS] : ['ui-dialog-panel', options.size === 'lg' ? 'ui-dialog-lg' : 'ui-dialog-md'],
      positionStrategy,
      injector: options.injector,
      closeOnNavigation: true,
    };
    return this.dialog.open<R, D, C>(component, config);
  }

  openSheet<C, D = unknown, R = unknown>(component: ComponentType<C>, options: UiDialogOptions<D> = {}): DialogRef<R, C> {
    return this.open<C, D, R>(component, { ...options, presentation: 'sheet' });
  }

  async confirm(data: UiConfirmDialogData): Promise<boolean> {
    const ref = this.open<UiConfirmDialog, UiConfirmDialogData, boolean>(UiConfirmDialog, { data });
    return (await firstValueFrom(ref.closed)) === true;
  }

  closeAll(): void {
    this.dialog.closeAll();
  }
}
