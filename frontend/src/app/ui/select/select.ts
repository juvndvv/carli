import { CdkListbox, CdkOption } from '@angular/cdk/listbox';
import { CdkConnectedOverlay, CdkOverlayOrigin, ConnectedPosition } from '@angular/cdk/overlay';
import {
  ChangeDetectionStrategy,
  Component,
  computed,
  ElementRef,
  forwardRef,
  input,
  model,
  signal,
  viewChild,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { UiIcon } from '../icon/icon';
import { OVERLAY_BELOW_THEN_ABOVE, UiSelectOption } from './select-option';

@Component({
  selector: 'ui-select',
  imports: [CdkOverlayOrigin, CdkConnectedOverlay, CdkListbox, CdkOption, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiSelect), multi: true }],
  template: `
    <button
      #trigger
      type="button"
      class="trigger"
      cdkOverlayOrigin
      #origin="cdkOverlayOrigin"
      aria-haspopup="listbox"
      [attr.id]="inputId()"
      [attr.aria-expanded]="open()"
      [attr.aria-label]="ariaLabel()"
      [disabled]="disabled()"
      (click)="toggle()"
      (keydown.arrowDown)="show($event)"
    >
      @if (selected()?.icon) {
        <ui-icon [name]="selected()!.icon!" />
      }
      <span class="label" [class.placeholder]="!selected()">{{ selected()?.label ?? placeholder() }}</span>
      <ui-icon name="chevron-down" class="chevron" [size]="16" />
    </button>
    <ng-template
      cdkConnectedOverlay
      [cdkConnectedOverlayOrigin]="origin"
      [cdkConnectedOverlayOpen]="open()"
      [cdkConnectedOverlayPositions]="positions"
      [cdkConnectedOverlayMinWidth]="minWidth()"
      (overlayOutsideClick)="close(false)"
      (detach)="close(false)"
      (attach)="focusList()"
    >
      <ul
        class="panel"
        cdkListbox
        #listbox="cdkListbox"
        [cdkListboxValue]="listboxValue()"
        [cdkListboxCompareWith]="compareWith()"
        (cdkListboxValueChange)="choose($event.value[0])"
        (keydown.escape)="close(true)"
        (keydown.tab)="close(false)"
        [attr.aria-label]="ariaLabel() ?? placeholder()"
      >
        @for (option of options(); track $index) {
          <li class="option" [cdkOption]="option.value" [cdkOptionDisabled]="!!option.disabled">
            @if (option.icon) {
              <ui-icon [name]="option.icon" />
            }
            <span class="text">
              {{ option.label }}
              @if (option.description) {
                <span class="description">{{ option.description }}</span>
              }
            </span>
            @if (isSelected(option.value)) {
              <ui-icon name="check" class="check" [size]="16" />
            }
          </li>
        } @empty {
          <li class="empty">Sin opciones</li>
        }
      </ul>
    </ng-template>
  `,
  styleUrl: './overlay-panel.css',
  styles: `
    :host {
      display: block;
      min-width: 0;
    }
    .trigger {
      display: flex;
      align-items: center;
      gap: 8px;
      width: 100%;
      height: 44px;
      padding: 0 12px;
      border: 1px solid var(--border);
      border-radius: var(--r-md);
      background: var(--surface);
      color: var(--text);
      text-align: left;
    }
    .trigger[aria-expanded='true'] {
      border-color: var(--text-3);
    }
    .trigger:disabled {
      opacity: 0.6;
      cursor: default;
    }
    .label {
      flex: 1;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .placeholder {
      color: var(--text-3);
    }
    .chevron {
      color: var(--text-3);
    }
  `,
})
export class UiSelect<T = string> implements ControlValueAccessor {
  readonly options = input<UiSelectOption<T>[]>([]);
  readonly value = model<T | null>(null);
  readonly placeholder = input('Selecciona una opción');
  readonly ariaLabel = input<string | null>(null);
  readonly inputId = input<string | null>(null);
  readonly compareWith = input<(a: T, b: T) => boolean>((a, b) => a === b);

  private readonly trigger = viewChild.required<ElementRef<HTMLButtonElement>>('trigger');
  private readonly listbox = viewChild<CdkListbox<T>>('listbox');
  protected readonly open = signal(false);
  protected readonly disabled = signal(false);
  protected readonly positions = OVERLAY_BELOW_THEN_ABOVE as unknown as ConnectedPosition[];
  protected readonly minWidth = signal(200);
  protected readonly selected = computed(() => {
    const value = this.value();
    return value === null ? null : (this.options().find((option) => this.compareWith()(option.value, value)) ?? null);
  });
  protected readonly listboxValue = computed(() => (this.value() === null ? [] : [this.value() as T]));
  private onChange: (value: T | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected isSelected(value: T): boolean {
    const current = this.value();
    return current !== null && this.compareWith()(value, current);
  }

  protected toggle(): void {
    if (this.open()) {
      this.close(false);
    } else {
      this.openPanel();
    }
  }

  protected show(event: Event): void {
    event.preventDefault();
    this.openPanel();
  }

  protected focusList(): void {
    queueMicrotask(() => this.listbox()?.focus());
  }

  protected choose(value: T | undefined): void {
    if (value === undefined) {
      return;
    }
    this.value.set(value);
    this.onChange(value);
    this.close(true);
  }

  protected close(restoreFocus: boolean): void {
    if (!this.open()) {
      return;
    }
    this.open.set(false);
    this.onTouched();
    if (restoreFocus) {
      this.trigger().nativeElement.focus();
    }
  }

  private openPanel(): void {
    this.minWidth.set(this.trigger().nativeElement.getBoundingClientRect().width);
    this.open.set(true);
  }

  writeValue(value: T | null): void {
    this.value.set(value ?? null);
  }

  registerOnChange(fn: (value: T | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
