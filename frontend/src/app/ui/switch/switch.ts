import { booleanAttribute, ChangeDetectionStrategy, Component, forwardRef, input, model, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Component({
  selector: 'ui-switch',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiSwitch), multi: true }],
  template: `
    <button
      type="button"
      role="switch"
      class="track"
      [class.on]="checked()"
      [attr.aria-checked]="checked()"
      [attr.aria-label]="label()"
      [disabled]="isDisabled()"
      (click)="toggle()"
    ></button>
  `,
  styles: `
    :host {
      display: inline-flex;
      flex: none;
    }
    .track {
      width: 40px;
      height: 24px;
      border-radius: 999px;
      background: var(--border);
      position: relative;
      border: 0;
      padding: 0;
      transition: background var(--motion-fast);
    }
    .track::after {
      content: '';
      position: absolute;
      top: 3px;
      left: 3px;
      width: 18px;
      height: 18px;
      border-radius: 50%;
      background: #fff;
      transition: left var(--motion-fast);
    }
    .track.on {
      background: var(--primary);
    }
    .track.on::after {
      left: 19px;
      background: var(--on-primary);
    }
    .track:focus-visible {
      border-radius: 999px;
    }
    .track:disabled {
      opacity: 0.5;
    }
  `,
})
export class UiSwitch implements ControlValueAccessor {
  readonly checked = model(false);
  readonly label = input.required<string>();
  readonly disabled = input(false, { transform: booleanAttribute });

  private readonly formDisabled = signal(false);
  protected readonly isDisabled = () => this.disabled() || this.formDisabled();
  private onChange: (value: boolean) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected toggle(): void {
    const next = !this.checked();
    this.checked.set(next);
    this.onChange(next);
    this.onTouched();
  }

  writeValue(value: boolean | null): void {
    this.checked.set(Boolean(value));
  }

  registerOnChange(fn: (value: boolean) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.formDisabled.set(disabled);
  }
}
