import {
  addDays,
  addMonths,
  daysBetween,
  formatShortDate,
  IsoDate,
  MONTHS_LONG,
  parseIsoDate,
  todayIso,
} from '../dates/dates';

export interface FinancialPeriodLike {
  start_date: IsoDate;
  end_date: IsoDate | null;
  expected_end_date?: IsoDate | null;
}

export function periodEffectiveEnd(period: FinancialPeriodLike): IsoDate {
  return period.end_date ?? period.expected_end_date ?? addDays(addMonths(period.start_date, 1), -1);
}

export function periodMajorityMonth(period: FinancialPeriodLike): { year: number; month: number } {
  const end = periodEffectiveEnd(period);
  const counts = new Map<string, number>();
  const total = Math.max(daysBetween(period.start_date, end), 0);
  for (let offset = 0; offset <= total; offset++) {
    const key = addDays(period.start_date, offset).slice(0, 7);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  let bestKey = period.start_date.slice(0, 7);
  let bestCount = -1;
  for (const [key, count] of counts) {
    if (count >= bestCount) {
      bestKey = key;
      bestCount = count;
    }
  }
  const [year, month] = bestKey.split('-').map(Number);
  return { year, month };
}

export function periodRangeLabel(period: FinancialPeriodLike, today: IsoDate = todayIso()): string {
  const start = parseIsoDate(period.start_date)!;
  const endValue = periodEffectiveEnd(period);
  const end = parseIsoDate(endValue)!;
  const crossesYear = start.year !== end.year;
  const startLabel = formatShortDate(period.start_date, crossesYear);
  if (period.end_date === null && today >= period.start_date && today <= endValue) {
    return `${startLabel} – hoy`;
  }
  return `${startLabel} – ${formatShortDate(endValue, crossesYear)}`;
}

export function periodName(period: FinancialPeriodLike, today: IsoDate = todayIso()): string {
  const { year, month } = periodMajorityMonth(period);
  const currentYear = parseIsoDate(today)?.year;
  const suffix = year === currentYear ? '' : ` ${year}`;
  return `Periodo de ${MONTHS_LONG[month - 1]}${suffix}`;
}

export function periodLabel(period: FinancialPeriodLike, today: IsoDate = todayIso()): string {
  const start = parseIsoDate(period.start_date)!;
  const end = parseIsoDate(periodEffectiveEnd(period))!;
  const crossesYear = start.year !== end.year;
  const range = `${formatShortDate(period.start_date, crossesYear)} – ${formatShortDate(periodEffectiveEnd(period), crossesYear)}`;
  return `${periodName(period, today)} (${range})`;
}

export function periodDaysLeft(period: FinancialPeriodLike, today: IsoDate = todayIso()): number {
  return Math.max(daysBetween(today, periodEffectiveEnd(period)), 0);
}

export function isPeriodOpen(period: FinancialPeriodLike): boolean {
  return period.end_date === null;
}
