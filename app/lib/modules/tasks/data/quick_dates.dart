import '../../../core/format/dates.dart' as dates;
import '../../../core/format/dates.dart' show capitalize, daysBetween, formatShortDate, monthsShort, weekdaysLong;

enum QuickDate {
  today('Hoy'),
  tomorrow('Mañana'),
  weekend('Fin de semana'),
  nextWeek('Próxima semana'),
  none('Sin fecha');

  const QuickDate(this.label);

  final String label;

  DateTime? resolve([DateTime? now]) {
    final current = dates.today(now);
    return switch (this) {
      QuickDate.today => current,
      QuickDate.tomorrow => current.add(const Duration(days: 1)),
      QuickDate.weekend =>
        current.weekday >= DateTime.saturday
            ? current.add(Duration(days: 7 - current.weekday + DateTime.saturday))
            : current.add(Duration(days: DateTime.saturday - current.weekday)),
      QuickDate.nextWeek => current.add(Duration(days: 8 - current.weekday)),
      QuickDate.none => null,
    };
  }
}

QuickDate? quickDateOf(DateTime? date, [DateTime? now]) {
  for (final option in QuickDate.values) {
    if (option.resolve(now) == (date == null ? null : dates.dateOnly(date))) return option;
  }
  return null;
}

String taskDueLabel(DateTime date, {DateTime? now}) {
  final offset = daysBetween(dates.today(now), date);
  return switch (offset) {
    0 => 'Hoy',
    1 => 'Mañana',
    -1 => 'Ayer',
    < -1 => 'Hace ${-offset} días',
    < 7 => capitalize(weekdaysLong[date.weekday - 1]),
    _ => formatShortDate(date, withYear: date.year != dates.today(now).year),
  };
}

String weekdayShortDate(DateTime date) =>
    '${weekdaysLong[date.weekday - 1].substring(0, 3)} ${date.day} ${monthsShort[date.month - 1]}';

String relativeDistance(DateTime date, {DateTime? now}) {
  final offset = daysBetween(dates.today(now), date);
  return switch (offset) {
    0 => 'hoy',
    1 => 'mañana',
    _ => 'en $offset días',
  };
}
