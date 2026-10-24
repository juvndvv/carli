import { addDays, formatFormDate, formatLongDate, formatRelativeDay, parseFormDate, todayIso } from './dates';
import { RelativeDatePipe } from './relative-date.pipe';

const TODAY = '2026-10-24';

describe('RelativeDatePipe', () => {
  const pipe = new RelativeDatePipe();

  it('labels today, yesterday and tomorrow', () => {
    expect(pipe.transform('2026-10-24', 'lower', TODAY)).toBe('Hoy');
    expect(pipe.transform('2026-10-23', 'lower', TODAY)).toBe('Ayer');
    expect(pipe.transform('2026-10-25', 'lower', TODAY)).toBe('Mañana');
  });

  it('uses weekday, day and short month for other dates', () => {
    expect(pipe.transform('2026-10-22', 'lower', TODAY)).toBe('jueves 22 oct');
    expect(pipe.transform('2026-10-20', 'lower', TODAY)).toBe('martes 20 oct');
    expect(pipe.transform('2026-09-28', 'lower', TODAY)).toBe('lunes 28 sep');
  });

  it('capitalizes in title style for day headers', () => {
    expect(pipe.transform('2026-10-22', 'title', TODAY)).toBe('Jueves 22 oct');
  });

  it('adds the year for dates outside the current year', () => {
    expect(pipe.transform('2025-12-31', 'lower', TODAY)).toBe('miércoles 31 dic 2025');
  });

  it('returns an empty string for missing values', () => {
    expect(pipe.transform(null)).toBe('');
  });
});

describe('date helpers', () => {
  it('computes today in Europe/Madrid regardless of UTC offset', () => {
    expect(todayIso(new Date('2026-10-24T22:30:00Z'))).toBe('2026-10-25');
    expect(todayIso(new Date('2026-10-24T21:30:00Z'))).toBe('2026-10-24');
  });

  it('moves across month and year boundaries', () => {
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });

  it('formats and parses form dates as dd/mm/aaaa', () => {
    expect(formatFormDate('2026-10-24')).toBe('24/10/2026');
    expect(parseFormDate('24/10/2026')).toBe('2026-10-24');
    expect(parseFormDate('31/02/2026')).toBeNull();
  });

  it('formats long dates for the launcher crumb', () => {
    expect(formatLongDate('2026-10-24')).toBe('Sábado, 24 de octubre');
  });

  it('keeps relative day output stable without a pipe', () => {
    expect(formatRelativeDay('2026-10-22', TODAY)).toBe('jueves 22 oct');
  });
});
