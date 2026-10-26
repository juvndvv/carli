import '../../../core/format/dates.dart';

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

/// Compact "when" for note rows: the time today, then Ayer, the weekday this week and the date before that.
String noteWhen(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final days = daysBetween(local, now ?? DateTime.now());
  return switch (days) {
    0 => _time(local),
    1 => 'Ayer',
    > 1 && < 7 => capitalize(weekdaysLong[local.weekday - 1].substring(0, 3)),
    _ => formatShortDate(local, withYear: local.year != (now ?? DateTime.now()).year),
  };
}

String editedLabel(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  return 'Editada ${formatRelativeDay(local, now: now)}, ${_time(local)}';
}

String restockReturnLabel(DateTime date, {DateTime? now}) {
  final days = daysBetween(now ?? DateTime.now(), date);
  if (days <= 0) return 'Vuelve hoy';
  if (days == 1) return 'Vuelve mañana';
  return 'Vuelve el ${weekdaysLong[date.weekday - 1].substring(0, 3)} ${formatShortDate(date)}';
}
