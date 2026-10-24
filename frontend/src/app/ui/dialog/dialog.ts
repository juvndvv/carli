import { InteractivityChecker } from '@angular/cdk/a11y';
import { DialogRef } from '@angular/cdk/dialog';
import {
  afterNextRender,
  booleanAttribute,
  ChangeDetectionStrategy,
  Component,
  computed,
  ElementRef,
  inject,
  input,
} from '@angular/core';
import { UiButton } from '../button/button';
import { SHEET_PANEL_CLASS } from './dialog-tokens';

let nextDialogId = 0;

const FOCUSABLE_SELECTOR = 'input:not([type="hidden"]), select, textarea, button, a[href], [tabindex]';

export function initialFocusTarget(host: HTMLElement, checker: InteractivityChecker): HTMLElement | null {
  const explicit = host.querySelector<HTMLElement>('[cdkFocusInitial]');
  if (explicit) {
    return explicit;
  }
  const isTabbable = (element: HTMLElement) =>
    checker.isFocusable(element, { ignoreVisibility: true }) && checker.isTabbable(element);
  for (const region of ['[data-dialog-body]', '[data-dialog-footer]']) {
    const candidates = host.querySelectorAll<HTMLElement>(`${region} :is(${FOCUSABLE_SELECTOR})`);
    const target = Array.from(candidates).find(isTabbable);
    if (target) {
      return target;
    }
  }
  return null;
}

@Component({
  selector: 'ui-dialog, ui-sheet',
  imports: [UiButton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class.sheet]': 'isSheet()' },
  template: `
    @if (isSheet()) {
      <span class="handle" aria-hidden="true"></span>
    }
    <header class="head">
      <div class="titles">
        <h2 [id]="titleId">{{ heading() }}</h2>
        @if (subtitle()) {
          <p class="small muted">{{ subtitle() }}</p>
        }
      </div>
      <ng-content select="[dialog-actions]" />
      @if (closable()) {
        <button
          ui-button
          type="button"
          variant="ghost"
          size="sm"
          icon="x"
          iconOnly
          aria-label="Cerrar"
          (click)="close()"
        ></button>
      }
    </header>
    <div class="body" data-dialog-body>
      <ng-content />
    </div>
    <div class="footer-slot" data-dialog-footer>
      <ng-content select="[dialog-footer]" />
    </div>
  `,
  styles: `
    :host {
      display: flex;
      flex-direction: column;
      gap: 16px;
      background: var(--surface);
      border-radius: var(--r-lg);
      box-shadow: var(--shadow-2);
      width: 100%;
      max-height: 92vh;
      overflow: auto;
      padding: 20px;
      animation: ui-dialog-in var(--motion-enter) ease-out;
    }
    :host(.sheet) {
      border-radius: var(--r-xl) var(--r-xl) 0 0;
      padding-top: 8px;
      padding-bottom: calc(20px + env(safe-area-inset-bottom));
      animation-name: ui-sheet-in;
    }
    .handle {
      align-self: center;
      width: 36px;
      height: 4px;
      border-radius: 999px;
      background: var(--border);
      margin-bottom: 4px;
    }
    .head {
      display: flex;
      align-items: flex-start;
      gap: 8px;
    }
    .titles {
      flex: 1;
      min-width: 0;
      padding-top: 4px;
    }
    .footer-slot {
      display: contents;
    }
    .body {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    @keyframes ui-dialog-in {
      from {
        transform: translateY(8px);
        opacity: 0;
      }
    }
    @keyframes ui-sheet-in {
      from {
        transform: translateY(32px);
        opacity: 0;
      }
    }
  `,
})
export class UiDialog {
  private readonly dialogRef = inject(DialogRef, { optional: true });

  readonly heading = input.required<string>();
  readonly subtitle = input<string | null>(null);
  readonly closable = input(true, { transform: booleanAttribute });

  protected readonly titleId = `ui-dialog-title-${nextDialogId++}`;
  protected readonly isSheet = computed(() => {
    const panelClass = this.dialogRef?.config.panelClass;
    return Array.isArray(panelClass) ? panelClass.includes(SHEET_PANEL_CLASS) : panelClass === SHEET_PANEL_CLASS;
  });

  constructor() {
    const host = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
    const checker = inject(InteractivityChecker);
    afterNextRender(() => {
      const container = host.closest('[role="dialog"], [role="alertdialog"]');
      if (container && !container.hasAttribute('aria-label')) {
        container.setAttribute('aria-labelledby', this.titleId);
      }
      if (this.dialogRef) {
        initialFocusTarget(host, checker)?.focus();
      }
    });
  }

  close(result?: unknown): void {
    this.dialogRef?.close(result);
  }
}
