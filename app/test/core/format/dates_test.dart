import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/format/dates.dart';

final now = DateTime(2026, 10, 24, 18, 30);

void main() {
  test('names today, yesterday and tomorrow', () {
    expect(formatRelativeDay(DateTime(2026, 10, 24), now: now), 'Hoy');
    expect(formatRelativeDay(DateTime(2026, 10, 23), now: now), 'Ayer');
    expect(formatRelativeDay(DateTime(2026, 10, 25), now: now), 'Mañana');
  });

  test('uses weekday and short date for other days', () {
    expect(formatRelativeDay(DateTime(2026, 10, 22), now: now), 'jueves 22 oct');
    expect(formatRelativeDay(DateTime(2026, 10, 20), now: now), 'martes 20 oct');
    expect(formatRelativeDay(DateTime(2026, 9, 28), now: now), 'lunes 28 sep');
    expect(formatRelativeDay(DateTime(2026, 10, 22), now: now, style: RelativeDateStyle.title), 'Jueves 22 oct');
  });

  test('adds the year outside the current one', () {
    expect(formatRelativeDay(DateTime(2025, 12, 31), now: now), 'miércoles 31 dic 2025');
  });

  test('counts calendar days across daylight saving changes', () {
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
  });

  test('formats and parses form dates', () {
    expect(formatFormDate(DateTime(2026, 10, 24)), '24/10/2026');
    expect(parseFormDate('24/10/2026'), DateTime(2026, 10, 24));
    expect(parseFormDate('31/02/2026'), isNull);
    expect(formatFormDate(null), '');
  });

  test('formats long dates', () {
    expect(formatLongDate(DateTime(2026, 10, 24)), 'Sábado, 24 de octubre');
  });
}
