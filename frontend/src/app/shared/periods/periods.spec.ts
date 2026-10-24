import { periodDaysLeft, periodLabel, periodName, periodRangeLabel } from './periods';

describe('period helpers', () => {
  it('names a closed period by the month holding most of its days', () => {
    const period = { start_date: '2026-10-28', end_date: '2026-11-26' };
    expect(periodName(period, '2026-11-02')).toBe('Periodo de noviembre');
    expect(periodLabel(period, '2026-11-02')).toBe('Periodo de noviembre (28 oct – 26 nov)');
  });

  it('uses the expected end for open periods and shows "hoy" in ranges', () => {
    const open = { start_date: '2026-09-28', end_date: null, expected_end_date: '2026-10-27' };
    expect(periodName(open, '2026-10-24')).toBe('Periodo de octubre');
    expect(periodRangeLabel(open, '2026-10-24')).toBe('28 sep – hoy');
    expect(periodDaysLeft(open, '2026-10-24')).toBe(3);
  });

  it('falls back to start plus one month when no end is known', () => {
    const open = { start_date: '2026-10-28', end_date: null };
    expect(periodLabel(open, '2026-10-30')).toBe('Periodo de noviembre (28 oct – 27 nov)');
  });

  it('adds years when a period crosses the new year', () => {
    const period = { start_date: '2026-12-28', end_date: '2027-01-27' };
    expect(periodLabel(period, '2027-01-02')).toBe('Periodo de enero (28 dic 2026 – 27 ene 2027)');
  });
});
