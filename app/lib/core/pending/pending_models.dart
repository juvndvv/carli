import 'package:flutter/foundation.dart';

typedef PendingJson = Map<String, dynamic>;

@immutable
class PendingItem {
  const PendingItem({
    required this.module,
    required this.type,
    required this.id,
    required this.title,
    required this.date,
    required this.route,
    this.subtitle,
    this.amountCents,
    this.meta = const {},
  });

  factory PendingItem.fromJson(PendingJson json) => PendingItem(
    module: json['module'] as String,
    type: json['type'] as String,
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String?,
    amountCents: (json['amount_cents'] as num?)?.toInt(),
    date: _parseDate(json['date'] as String),
    route: json['route'] as String? ?? '/',
    meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : const {},
  );

  final String module;
  final String type;
  final String id;
  final String title;
  final String? subtitle;
  final int? amountCents;
  final DateTime date;
  final String route;
  final Map<String, dynamic> meta;

  String get key => pendingKey(module, type, id);

  String? metaString(String name) {
    final value = meta[name];
    return value is String && value.isNotEmpty ? value : null;
  }
}

String pendingKey(String module, String type, [String? id]) => id == null ? '$module:$type' : '$module:$type:$id';

DateTime _parseDate(String value) {
  final parts = value.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

@immutable
class PendingSummaryEntry {
  const PendingSummaryEntry({required this.module, required this.moduleName, required this.type, required this.count});

  factory PendingSummaryEntry.fromJson(PendingJson json) => PendingSummaryEntry(
    module: json['module'] as String,
    moduleName: json['module_name'] as String? ?? json['module'] as String,
    type: json['type'] as String,
    count: (json['count'] as num?)?.toInt() ?? 0,
  );

  final String module;
  final String moduleName;
  final String type;
  final int count;

  PendingSummaryEntry withCount(int value) =>
      PendingSummaryEntry(module: module, moduleName: moduleName, type: type, count: value);
}

@immutable
class PendingSummary {
  const PendingSummary({required this.total, required this.entries});

  factory PendingSummary.fromJson(PendingJson json) => PendingSummary(
    total: (json['total'] as num?)?.toInt() ?? 0,
    entries: [
      for (final entry in json['by_module'] as List? ?? const [])
        PendingSummaryEntry.fromJson(Map<String, dynamic>.from(entry as Map)),
    ],
  );

  static const empty = PendingSummary(total: 0, entries: []);

  final int total;
  final List<PendingSummaryEntry> entries;

  int count(String module, [String? type]) => entries
      .where((entry) => entry.module == module && (type == null || entry.type == type))
      .fold(0, (sum, entry) => sum + entry.count);

  PendingSummary without(PendingItem item) {
    final index = entries.indexWhere((entry) => entry.module == item.module && entry.type == item.type);
    if (index < 0 || entries[index].count == 0) return this;
    return PendingSummary(
      total: total > 0 ? total - 1 : 0,
      entries: [
        for (final (position, entry) in entries.indexed)
          if (position != index) entry else if (entry.count > 1) entry.withCount(entry.count - 1),
      ],
    );
  }
}

@immutable
class PendingPage {
  const PendingPage({required this.items, required this.nextCursor});

  factory PendingPage.fromJson(PendingJson json) {
    final meta = json['meta'] is Map ? json['meta'] as Map : const {};
    return PendingPage(
      items: [
        for (final item in json['data'] as List? ?? const [])
          PendingItem.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      nextCursor: meta['has_more'] == true ? meta['next_cursor'] as String? : null,
    );
  }

  final List<PendingItem> items;
  final String? nextCursor;
}

@immutable
class PendingFilter {
  const PendingFilter({this.module, this.type});

  static const all = PendingFilter();

  final String? module;
  final String? type;

  bool get isFiltered => module != null || type != null;

  bool matches(PendingSummaryEntry entry) => entry.module == module && entry.type == type;

  Map<String, String> get queryParameters => {PendingQuery.module: ?module, PendingQuery.type: ?type};

  @override
  bool operator ==(Object other) => other is PendingFilter && other.module == module && other.type == type;

  @override
  int get hashCode => Object.hash(module, type);
}

abstract final class PendingQuery {
  static const module = 'modulo';
  static const type = 'tipo';
}

String pendingTotalLabel(int total) => switch (total) {
  0 => 'Nada por revisar',
  1 => '1 elemento por revisar',
  _ => '$total elementos por revisar',
};
