typedef Json = Map<String, dynamic>;

DateTime parseIsoDate(String value) {
  final parts = value.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

DateTime? parseIsoDateOrNull(Object? value) => value is String ? parseIsoDate(value) : null;

String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

List<T> parseList<T>(Object? value, T Function(Json) parse) =>
    value is List ? [for (final item in value) parse(item as Json)] : <T>[];

int intOf(Object? value) => (value as num?)?.toInt() ?? 0;

int? intOrNull(Object? value) => (value as num?)?.toInt();
