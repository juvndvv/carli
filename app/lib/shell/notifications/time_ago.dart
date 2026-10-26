import '../../core/format/dates.dart';

int _jsRound(double value) => (value + 0.5).floor();

String _plural(int count, String singular, String plural) => count == 1 ? singular : plural;

String _relative(int amount, String singular, String plural) {
  final unit = _plural(amount.abs(), singular, plural);
  return amount < 0 ? 'hace ${-amount} $unit' : 'dentro de $amount $unit';
}

String _relativeDays(int days) => switch (days) {
  -2 => 'anteayer',
  -1 => 'ayer',
  0 => 'hoy',
  1 => 'mañana',
  2 => 'pasado mañana',
  _ => _relative(days, 'día', 'días'),
};

String formatTimeAgo(DateTime? instant, {DateTime? now}) {
  if (instant == null) return '';
  final reference = now ?? DateTime.now();
  final seconds = _jsRound(instant.difference(reference).inMilliseconds / 1000);
  final absolute = seconds.abs();
  if (absolute < 60) return 'ahora';
  if (absolute < 3600) return _relative(_jsRound(seconds / 60), 'minuto', 'minutos');
  if (absolute < 86400) return _relative(_jsRound(seconds / 3600), 'hora', 'horas');
  if (absolute < 7 * 86400) return _relativeDays(_jsRound(seconds / 86400));
  return formatShortDate(instant.toLocal());
}
