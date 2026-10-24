export const APP_TIME_ZONE = 'Europe/Madrid';

export type IsoDate = string;

export const MONTHS_SHORT = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

export const MONTHS_LONG = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

export const WEEKDAYS_LONG = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];

export const WEEKDAYS_MONDAY_FIRST_SHORT = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})/;

const isoFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: APP_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

export function toIsoDate(instant: Date = new Date()): IsoDate {
  return isoFormatter.format(instant);
}

export function todayIso(now: Date = new Date()): IsoDate {
  return toIsoDate(now);
}

export function parseIsoDate(value: IsoDate): { year: number; month: number; day: number } | null {
  const match = ISO_DATE.exec(value);
  if (!match) {
    return null;
  }
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

export function isoToUtcDate(value: IsoDate): Date {
  const parts = parseIsoDate(value);
  if (!parts) {
    throw new Error(`Invalid ISO date: ${value}`);
  }
  return new Date(Date.UTC(parts.year, parts.month - 1, parts.day));
}

export function utcDateToIso(date: Date): IsoDate {
  return date.toISOString().slice(0, 10);
}

export function addDays(value: IsoDate, days: number): IsoDate {
  const date = isoToUtcDate(value);
  date.setUTCDate(date.getUTCDate() + days);
  return utcDateToIso(date);
}

export function addMonths(value: IsoDate, months: number): IsoDate {
  const parts = parseIsoDate(value)!;
  const target = new Date(Date.UTC(parts.year, parts.month - 1 + months, 1));
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
  target.setUTCDate(Math.min(parts.day, lastDay));
  return utcDateToIso(target);
}

export function daysBetween(from: IsoDate, to: IsoDate): number {
  return Math.round((isoToUtcDate(to).getTime() - isoToUtcDate(from).getTime()) / 86_400_000);
}

export function weekdayIndex(value: IsoDate): number {
  return isoToUtcDate(value).getUTCDay();
}

export function formatShortDate(value: IsoDate, withYear = false): string {
  const parts = parseIsoDate(value);
  if (!parts) {
    return value;
  }
  const base = `${parts.day} ${MONTHS_SHORT[parts.month - 1]}`;
  return withYear ? `${base} ${parts.year}` : base;
}

export function formatFormDate(value: IsoDate | null | undefined): string {
  const parts = value ? parseIsoDate(value) : null;
  if (!parts) {
    return '';
  }
  return `${String(parts.day).padStart(2, '0')}/${String(parts.month).padStart(2, '0')}/${parts.year}`;
}

export function parseFormDate(value: string): IsoDate | null {
  const match = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(value.trim());
  if (!match) {
    return null;
  }
  const [day, month, year] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return null;
  }
  return utcDateToIso(date);
}

export function formatLongDate(value: IsoDate): string {
  const parts = parseIsoDate(value)!;
  return `${capitalize(WEEKDAYS_LONG[weekdayIndex(value)])}, ${parts.day} de ${MONTHS_LONG[parts.month - 1]}`;
}

export type RelativeDateStyle = 'lower' | 'title';

export function formatRelativeDay(value: IsoDate, today: IsoDate = todayIso(), style: RelativeDateStyle = 'lower'): string {
  const parts = parseIsoDate(value);
  if (!parts) {
    return value;
  }
  const offset = daysBetween(today, value);
  let label: string;
  if (offset === 0) {
    label = 'hoy';
  } else if (offset === -1) {
    label = 'ayer';
  } else if (offset === 1) {
    label = 'mañana';
  } else {
    const sameYear = parts.year === parseIsoDate(today)?.year;
    label = `${WEEKDAYS_LONG[weekdayIndex(value)]} ${formatShortDate(value, !sameYear)}`;
  }
  return offset >= -1 && offset <= 1 ? capitalize(label) : style === 'title' ? capitalize(label) : label;
}

export function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}
