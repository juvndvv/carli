const monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const monthsLong = [
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

const weekdaysLong = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

const weekdaysMondayFirstShort = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

String formatShortDate(DateTime value, {bool withYear = false}) {
  final base = '${value.day} ${monthsShort[value.month - 1]}';
  return withYear ? '$base ${value.year}' : base;
}

String formatFormDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

DateTime? parseFormDate(String value) {
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value.trim());
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) return null;
  return date;
}

String formatLongDate(DateTime value) =>
    '${capitalize(weekdaysLong[value.weekday - 1])}, ${value.day} de ${monthsLong[value.month - 1]}';

enum RelativeDateStyle { lower, title }

String formatRelativeDay(DateTime value, {DateTime? now, RelativeDateStyle style = RelativeDateStyle.lower}) {
  final reference = today(now);
  final offset = daysBetween(reference, value);
  final label = switch (offset) {
    0 => 'hoy',
    -1 => 'ayer',
    1 => 'mañana',
    _ => '${weekdaysLong[value.weekday - 1]} ${formatShortDate(value, withYear: value.year != reference.year)}',
  };
  return offset.abs() <= 1 || style == RelativeDateStyle.title ? capitalize(label) : label;
}

DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, date.day > lastDay ? lastDay : date.day);
}
