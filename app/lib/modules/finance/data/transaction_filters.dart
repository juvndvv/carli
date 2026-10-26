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
    this.debtId,
    this.recurringRuleId,
    this.contactId,
  });

  factory TransactionFilters.fromQuery(Map<String, List<String>> query) {
    List<String> list(String key) => [
      for (final value in query[key] ?? const <String>[])
        for (final item in value.split(','))
          if (item.trim().isNotEmpty) item.trim(),
    ];
    String? single(String key) => list(key).firstOrNull;
    DateTime? date(String key) {
      final text = single(key);
      return text != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ? parseIsoDate(text) : null;
    }

    Cents? cents(String key) {
      final text = single(key);
      return text != null && RegExp(r'^\d+$').hasMatch(text) ? int.parse(text) : null;
    }

    final queryText = single(TransactionQuery.text) ?? '';
    final from = date(TransactionQuery.from);
    final to = date(TransactionQuery.to);
    final rawPeriod = single(TransactionQuery.period);
    final implicitAll = queryText.isNotEmpty || from != null || to != null;
    final (scope, periodId) = switch (rawPeriod) {
      'todos' => (PeriodScope.all, null),
      'actual' => (PeriodScope.current, null),
      final String id => (PeriodScope.specific, id),
      null => (implicitAll ? PeriodScope.all : PeriodScope.current, null),
    };
    return TransactionFilters(
      periodScope: scope,
      periodId: periodId,
      accountIds: list(TransactionQuery.accounts).toSet(),
      categoryIds: list(TransactionQuery.categories).toSet(),
      tags: {for (final tag in list(TransactionQuery.tags)) tag.replaceFirst(RegExp('^#'), '').toLowerCase()},
      kinds: {for (final kind in list(TransactionQuery.kinds)) ?_kindParams[kind]},
      min: cents(TransactionQuery.min),
      max: cents(TransactionQuery.max),
      query: queryText,
      status: _statusParams[single(TransactionQuery.status)],
      uncategorized: _truthy.contains(single(TransactionQuery.uncategorized)?.toLowerCase()),
      from: from,
      to: to,
      debtId: single(TransactionQuery.debt),
      recurringRuleId: single(TransactionQuery.recurringRule),
      contactId: single(TransactionQuery.contact),
    );
  }

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
  final String? debtId;
  final String? recurringRuleId;
  final String? contactId;

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
    ValueGetter<String?>? debtId,
    ValueGetter<String?>? recurringRuleId,
    ValueGetter<String?>? contactId,
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
    debtId: debtId == null ? this.debtId : debtId(),
    recurringRuleId: recurringRuleId == null ? this.recurringRuleId : recurringRuleId(),
    contactId: contactId == null ? this.contactId : contactId(),
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
    debtId != null,
    recurringRuleId != null,
    contactId != null,
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
    'debt_id': debtId,
    'recurring_rule_id': recurringRuleId,
    'contact_id': contactId,
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
      other.to == to &&
      other.debtId == debtId &&
      other.recurringRuleId == recurringRuleId &&
      other.contactId == contactId;

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
    debtId,
    recurringRuleId,
    contactId,
  );
}

abstract final class TransactionQuery {
  static const period = 'periodo';
  static const from = 'desde';
  static const to = 'hasta';
  static const accounts = 'cuenta';
  static const categories = 'categoria';
  static const tags = 'etiqueta';
  static const kinds = 'tipo';
  static const min = 'min';
  static const max = 'max';
  static const text = 'q';
  static const status = 'estado';
  static const uncategorized = 'sin_categoria';
  static const debt = 'deuda';
  static const recurringRule = 'recurrente';
  static const contact = 'contacto';
  static const quickAdd = 'nuevo';
}

const _kindParams = {
  'gasto': TransactionKind.expense,
  'gastos': TransactionKind.expense,
  'expense': TransactionKind.expense,
  'ingreso': TransactionKind.income,
  'ingresos': TransactionKind.income,
  'income': TransactionKind.income,
  'transferencia': TransactionKind.transfer,
  'transferencias': TransactionKind.transfer,
  'transfer': TransactionKind.transfer,
  'ajuste': TransactionKind.adjustment,
  'adjustment': TransactionKind.adjustment,
};

const _statusParams = {
  'pendiente': TransactionStatus.pending,
  'pending': TransactionStatus.pending,
  'confirmado': TransactionStatus.cleared,
  'cleared': TransactionStatus.cleared,
};

const _truthy = {'1', 'true', 'si', 'sí'};

final transactionFiltersProvider = NotifierProvider<TransactionFiltersController, TransactionFilters>(
  TransactionFiltersController.new,
);

class TransactionFiltersController extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();

  void update(TransactionFilters Function(TransactionFilters current) change) => state = change(state);

  void replace(TransactionFilters filters) => state = filters;
}
