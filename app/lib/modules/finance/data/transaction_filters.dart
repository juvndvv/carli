import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_api.dart';
import 'json.dart';
import 'models.dart';

const uncategorizedFilter = 'none';

enum PeriodScope { current, all, specific }

@immutable
class TransactionFilters {
  const TransactionFilters({
    this.periodScope = PeriodScope.current,
    this.periodId,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.kinds = const {},
    this.query = '',
    this.status,
    this.uncategorized = false,
    this.tags = const {},
    this.min,
    this.max,
    this.from,
    this.to,
  });

  final PeriodScope periodScope;
  final String? periodId;
  final Set<String> accountIds;
  final Set<String> categoryIds;
  final Set<TransactionKind> kinds;
  final String query;
  final TransactionStatus? status;
  final bool uncategorized;
  final Set<String> tags;
  final Cents? min;
  final Cents? max;
  final DateTime? from;
  final DateTime? to;

  bool get hasDateRange => from != null || to != null;

  bool get moreFiltersActive => min != null || max != null || hasDateRange || status == TransactionStatus.cleared;

  TransactionFilters copyWith({
    PeriodScope? periodScope,
    ValueGetter<String?>? periodId,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<TransactionKind>? kinds,
    String? query,
    ValueGetter<TransactionStatus?>? status,
    bool? uncategorized,
    Set<String>? tags,
    ValueGetter<Cents?>? min,
    ValueGetter<Cents?>? max,
    ValueGetter<DateTime?>? from,
    ValueGetter<DateTime?>? to,
  }) => TransactionFilters(
    periodScope: periodScope ?? this.periodScope,
    periodId: periodId == null ? this.periodId : periodId(),
    accountIds: accountIds ?? this.accountIds,
    categoryIds: categoryIds ?? this.categoryIds,
    kinds: kinds ?? this.kinds,
    query: query ?? this.query,
    status: status == null ? this.status : status(),
    uncategorized: uncategorized ?? this.uncategorized,
    tags: tags ?? this.tags,
    min: min == null ? this.min : min(),
    max: max == null ? this.max : max(),
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
  );

  TransactionFilters withPeriod(Period? period) {
    final cleared = copyWith(from: () => null, to: () => null);
    return period == null
        ? cleared.copyWith(periodScope: PeriodScope.all, periodId: () => null)
        : period.isCurrent
        ? cleared.copyWith(periodScope: PeriodScope.current, periodId: () => null)
        : cleared.copyWith(periodScope: PeriodScope.specific, periodId: () => period.id);
  }

  int get activeCount => [
    accountIds.isNotEmpty,
    categoryIds.isNotEmpty,
    tags.isNotEmpty,
    kinds.isNotEmpty,
    min != null || max != null,
    status != null,
    uncategorized,
    hasDateRange,
  ].where((active) => active).length;

  bool get onlyUncategorized => uncategorized && activeCount == 1 && query.isEmpty;

  TransactionFilters cleared() => TransactionFilters(periodScope: periodScope, periodId: periodId);

  Query toApiQuery(String? currentPeriodId) => {
    'period_id': hasDateRange
        ? null
        : switch (periodScope) {
            PeriodScope.all => null,
            PeriodScope.current => currentPeriodId,
            PeriodScope.specific => periodId,
          },
    'from': from == null ? null : isoDate(from!),
    'to': to == null ? null : isoDate(to!),
    'account_id': accountIds.toList()..sort(),
    'category_id': categoryIds.toList()..sort(),
    'tag': tags.toList()..sort(),
    'kind': [for (final kind in kinds) kind.api]..sort(),
    'min': min,
    'max': max,
    'q': query.trim().isEmpty ? null : query.trim(),
    'status': status?.api,
    'uncategorized': uncategorized ? 1 : null,
  };

  @override
  bool operator ==(Object other) =>
      other is TransactionFilters &&
      other.periodScope == periodScope &&
      other.periodId == periodId &&
      setEquals(other.accountIds, accountIds) &&
      setEquals(other.categoryIds, categoryIds) &&
      setEquals(other.kinds, kinds) &&
      setEquals(other.tags, tags) &&
      other.query == query &&
      other.status == status &&
      other.uncategorized == uncategorized &&
      other.min == min &&
      other.max == max &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(
    periodScope,
    periodId,
    Object.hashAllUnordered(accountIds),
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(kinds),
    Object.hashAllUnordered(tags),
    query,
    status,
    uncategorized,
    min,
    max,
    from,
    to,
  );
}

final transactionFiltersProvider = NotifierProvider<TransactionFiltersController, TransactionFilters>(
  TransactionFiltersController.new,
);

class TransactionFiltersController extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();

  void update(TransactionFilters Function(TransactionFilters current) change) => state = change(state);

  void replace(TransactionFilters filters) => state = filters;
}
