import { CdkConnectedOverlay, CdkOverlayOrigin, ConnectedPosition } from '@angular/cdk/overlay';
import { ChangeDetectionStrategy, Component, computed, forwardRef, input, model, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { addDays, formatFormDate, IsoDate, todayIso } from '@shared/dates/dates';
import { UiCalendar } from '../calendar/calendar';
import { UiChip } from '../chip/chip';
import { OVERLAY_BELOW_THEN_ABOVE } from '../select/select-option';

@Component({
  selector: 'ui-date-picker',
  imports: [UiChip, UiCalendar, CdkOverlayOrigin, CdkConnectedOverlay],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => UiDatePicker), multi: true }],
  host: { role: 'group', '[attr.aria-label]': 'ariaLabel()' },
  template: `
    <button type="button" ui-chip [selected]="value() === today()" [disabled]="disabled()" (click)="select(today())">
      Hoy
    </button>
    <button
      type="button"
      ui-chip
      [selected]="value() === yesterday()"
      [disabled]="disabled()"
      (click)="select(yesterday())"
    >
      Ayer
    </button>
    <button
      type="button"
      ui-chip
      icon="calendar"
      cdkOverlayOrigin
      #origin="cdkOverlayOrigin"
      [selected]="isOtherDay()"
      [pressable]="false"
      [attr.aria-label]="isOtherDay() ? 'Fecha: ' + formatted() : 'Elegir otra fecha'"
      [attr.aria-expanded]="open()"
      [disabled]="disabled()"
      (click)="open.set(!open())"
    >
      @if (isOtherDay()) {
        <span class="num">{{ formatted() }}</span>
      }
    </button>
    <ng-template
      cdkConnectedOverlay
      [cdkConnectedOverlayOrigin]="origin"
      [cdkConnectedOverlayOpen]="open()"
      [cdkConnectedOverlayPositions]="positions"
      (overlayOutsideClick)="open.set(false)"
      (detach)="open.set(false)"
    >
      <ui-calendar
        class="panel"
        [value]="value()"
        [min]="min()"
        [max]="max()"
        (picked)="select($event)"
        (keydown.escape)="open.set(false)"
      />
    </ng-template>
  `,
  styles: `
    :host {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      align-items: center;
    }
    .panel {
      background: var(--surface);
      border-radius: 16px;
      box-shadow: var(--shadow-2);
    }
  `,
})
export class UiDatePicker implements ControlValueAccessor {
  readonly value = model<IsoDate | null>(todayIso());
  readonly min = input<IsoDate | null>(null);
  readonly max = input<IsoDate | null>(null);
  readonly ariaLabel = input('Fecha');

  protected readonly positions = OVERLAY_BELOW_THEN_ABOVE as unknown as ConnectedPosition[];
  protected readonly open = signal(false);
  protected readonly disabled = signal(false);
  protected readonly today = computed(() => todayIso());
  protected readonly yesterday = computed(() => addDays(this.today(), -1));
  protected readonly isOtherDay = computed(() => {
    const value = this.value();
    return value !== null && value !== this.today() && value !== this.yesterday();
  });
  protected readonly formatted = computed(() => formatFormDate(this.value()));
  private onChange: (value: IsoDate | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected select(value: IsoDate): void {
    this.value.set(value);
    this.open.set(false);
    this.onChange(value);
    this.onTouched();
  }

  writeValue(value: IsoDate | null): void {
    this.value.set(value ?? null);
  }

  registerOnChange(fn: (value: IsoDate | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
