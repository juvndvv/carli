import {
  afterNextRender,
  ChangeDetectionStrategy,
  Component,
  computed,
  ElementRef,
  inject,
  Injector,
  input,
  linkedSignal,
  output,
} from '@angular/core';
import {
  addDays,
  addMonths,
  IsoDate,
  isoToUtcDate,
  MONTHS_LONG,
  todayIso,
  WEEKDAYS_LONG,
  WEEKDAYS_MONDAY_FIRST_SHORT,
} from '@shared/dates/dates';
import { UiIcon } from '../icon/icon';

interface CalendarDay {
  iso: IsoDate;
  day: number;
  label: string;
  inMonth: boolean;
  disabled: boolean;
}

const KEY_OFFSETS: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };

export function calendarDayLabel(iso: IsoDate): string {
  const [year, month, day] = iso.split('-').map(Number);
  return `${day} de ${MONTHS_LONG[month - 1]} de ${year}`;
}

@Component({
  selector: 'ui-calendar',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="head">
      <button type="button" class="nav" aria-label="Mes anterior" (click)="shiftMonth(-1)">
        <ui-icon name="chevron-left" />
      </button>
      <span class="title" aria-live="polite">{{ title() }}</span>
      <button type="button" class="nav" aria-label="Mes siguiente" (click)="shiftMonth(1)">
        <ui-icon name="chevron-right" />
      </button>
    </div>
    <div class="grid" role="grid" [attr.aria-label]="title()" (keydown)="onKeydown($event)">
      <div class="row" role="row">
        @for (weekday of weekdays; track $index) {
          <span class="weekday" role="columnheader" [attr.aria-label]="weekdayNames[$index]">{{ weekday }}</span>
        }
      </div>
      @for (week of weeks(); track week[0].iso) {
        <div class="row" role="row">
          @for (day of week; track day.iso) {
            <span class="cell" role="gridcell" [attr.aria-selected]="day.iso === value()">
              <button
                type="button"
                class="day"
                [class.out]="!day.inMonth"
                [class.today]="day.iso === today()"
                [class.selected]="day.iso === value()"
                [attr.data-iso]="day.iso"
                [attr.aria-label]="day.label"
                [attr.aria-current]="day.iso === today() ? 'date' : null"
                [tabIndex]="day.iso === focusedIso() ? 0 : -1"
                [disabled]="day.disabled"
                (click)="pick(day)"
              >
                {{ day.day }}
              </button>
            </span>
          }
        </div>
      }
    </div>
  `,
  styles: `
    :host {
      display: block;
      width: 280px;
      padding: 12px;
    }
    .head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 8px;
    }
    .title {
      font-weight: 600;
      text-transform: capitalize;
    }
    .nav {
      width: 32px;
      height: 32px;
      border: 0;
      border-radius: 999px;
      background: none;
      display: grid;
      place-items: center;
      color: var(--text);
    }
    .nav:hover {
      background: var(--surface-2);
    }
    .grid {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .row {
      display: grid;
      grid-template-columns: repeat(7, 1fr);
      gap: 2px;
      text-align: center;
    }
    .cell {
      display: flex;
    }
    .weekday {
      font-size: 12px;
      color: var(--text-3);
      font-weight: 500;
      padding: 4px 0;
    }
    .day {
      flex: 1;
      height: 36px;
      border: 0;
      border-radius: 999px;
      background: none;
      color: var(--text);
      font-variant-numeric: tabular-nums;
      font-size: 14px;
    }
    .day:hover {
      background: var(--surface-2);
    }
    .day:focus-visible {
      outline: 2px solid var(--focus, var(--primary));
      outline-offset: 1px;
    }
    .day.out {
      color: var(--text-3);
    }
    .day.today {
      font-weight: 700;
      box-shadow: inset 0 0 0 1px var(--border);
    }
    .day.selected {
      background: var(--primary);
      color: var(--on-primary);
    }
    .day:disabled {
      opacity: 0.35;
      cursor: default;
    }
  `,
})
export class UiCalendar {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
  private readonly injector = inject(Injector);

  readonly value = input<IsoDate | null>(null);
  readonly min = input<IsoDate | null>(null);
  readonly max = input<IsoDate | null>(null);
  readonly picked = output<IsoDate>();

  protected readonly weekdays = WEEKDAYS_MONDAY_FIRST_SHORT;
  protected readonly weekdayNames = [...WEEKDAYS_LONG.slice(1), WEEKDAYS_LONG[0]];
  protected readonly today = computed(() => todayIso());
  protected readonly focusedIso = linkedSignal<IsoDate>(() => this.value() ?? this.today());
  protected readonly month = computed(() => this.focusedIso().slice(0, 7));
  protected readonly title = computed(() => {
    const [year, month] = this.month().split('-').map(Number);
    return `${MONTHS_LONG[month - 1]} ${year}`;
  });
  protected readonly days = computed<CalendarDay[]>(() => {
    const first = `${this.month()}-01`;
    const mondayOffset = (isoToUtcDate(first).getUTCDay() + 6) % 7;
    const start = addDays(first, -mondayOffset);
    const min = this.min();
    const max = this.max();
    return Array.from({ length: 42 }, (_, index) => {
      const iso = addDays(start, index);
      return {
        iso,
        day: Number(iso.slice(8, 10)),
        label: calendarDayLabel(iso),
        inMonth: iso.startsWith(this.month()),
        disabled: (min !== null && iso < min) || (max !== null && iso > max),
      };
    });
  });
  protected readonly weeks = computed(() => {
    const days = this.days();
    return Array.from({ length: 6 }, (_, week) => days.slice(week * 7, week * 7 + 7));
  });

  protected shiftMonth(delta: number): void {
    this.focusedIso.set(addMonths(this.focusedIso(), delta));
  }

  protected pick(day: CalendarDay): void {
    this.focusedIso.set(day.iso);
    this.picked.emit(day.iso);
  }

  protected onKeydown(event: KeyboardEvent): void {
    const target = this.keyTarget(event);
    if (!target) {
      return;
    }
    event.preventDefault();
    this.focusedIso.set(target);
    afterNextRender(() => this.host.querySelector<HTMLButtonElement>(`button[data-iso="${target}"]`)?.focus(), {
      injector: this.injector,
    });
  }

  private keyTarget(event: KeyboardEvent): IsoDate | null {
    const current = this.focusedIso();
    if (event.key in KEY_OFFSETS) {
      return addDays(current, KEY_OFFSETS[event.key]);
    }
    const weekday = (isoToUtcDate(current).getUTCDay() + 6) % 7;
    switch (event.key) {
      case 'Home':
        return addDays(current, -weekday);
      case 'End':
        return addDays(current, 6 - weekday);
      case 'PageUp':
        return addMonths(current, event.shiftKey ? -12 : -1);
      case 'PageDown':
        return addMonths(current, event.shiftKey ? 12 : 1);
      default:
        return null;
    }
  }
}
