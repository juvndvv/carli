import { ConnectedPosition, createFlexibleConnectedPositionStrategy, createOverlayRef, OverlayRef } from '@angular/cdk/overlay';
import { ComponentPortal } from '@angular/cdk/portal';
import {
  ChangeDetectionStrategy,
  Component,
  Directive,
  ElementRef,
  inject,
  Injector,
  input,
  OnDestroy,
  signal,
} from '@angular/core';

let nextTooltipId = 0;

@Component({
  selector: 'ui-tooltip-panel',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { role: 'tooltip', '[attr.id]': 'id()' },
  template: `{{ text() }}`,
  styles: `
    :host {
      display: block;
      background: var(--text);
      color: var(--bg);
      border-radius: var(--r-sm);
      padding: 8px 10px;
      font-size: 13px;
      line-height: 18px;
      max-width: 280px;
      pointer-events: none;
    }
  `,
})
export class UiTooltipPanel {
  readonly text = signal('');
  readonly id = signal('');
}

const POSITIONS: ConnectedPosition[] = [
  { originX: 'center', originY: 'top', overlayX: 'center', overlayY: 'bottom', offsetY: -8 },
  { originX: 'center', originY: 'bottom', overlayX: 'center', overlayY: 'top', offsetY: 8 },
];

@Directive({
  selector: '[uiTooltip]',
  host: {
    '(mouseenter)': 'show()',
    '(mouseleave)': 'hide()',
    '(focusin)': 'show()',
    '(focusout)': 'hide()',
    '(keydown.escape)': 'hide()',
    '[attr.aria-describedby]': 'visible() ? id : null',
  },
})
export class UiTooltip implements OnDestroy {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);
  private readonly injector = inject(Injector);
  private overlayRef: OverlayRef | null = null;

  readonly uiTooltip = input.required<string>();
  protected readonly visible = signal(false);
  protected readonly id = `ui-tooltip-${nextTooltipId++}`;

  show(): void {
    const text = this.uiTooltip();
    if (!text || this.visible()) {
      return;
    }
    this.overlayRef ??= createOverlayRef(this.injector, {
      positionStrategy: createFlexibleConnectedPositionStrategy(this.injector, this.host).withPositions(POSITIONS),
    });
    const componentRef = this.overlayRef.attach(new ComponentPortal(UiTooltipPanel, null, this.injector));
    componentRef.instance.text.set(text);
    componentRef.instance.id.set(this.id);
    this.visible.set(true);
  }

  hide(): void {
    if (this.overlayRef?.hasAttached()) {
      this.overlayRef.detach();
    }
    this.visible.set(false);
  }

  ngOnDestroy(): void {
    this.overlayRef?.dispose();
  }
}
