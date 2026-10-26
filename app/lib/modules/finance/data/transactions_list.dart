import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_api.dart';
import 'finance_changes.dart';
import 'finance_providers.dart';
import 'models.dart';
import 'transaction_filters.dart';

const transactionsPageSize = 50;

@immutable
class TransactionListState {
  const TransactionListState({
    required this.items,
    required this.totals,
    required this.nextCursor,
    required this.hasMore,
    required this.pendingCount,
    this.loadingMore = false,
  });

  final List<Transaction> items;
  final TransactionTotals totals;
  final String? nextCursor;
  final bool hasMore;
  final int? pendingCount;
  final bool loadingMore;

  TransactionListState copyWith({List<Transaction>? items, String? nextCursor, bool? hasMore, bool? loadingMore}) =>
      TransactionListState(
        items: items ?? this.items,
        totals: totals,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        pendingCount: pendingCount,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class DayGroup {
  DayGroup(this.date);

  final DateTime date;
  final List<Transaction> items = [];
  Cents total = 0;
}

List<DayGroup> groupByDay(List<Transaction> transactions, {required bool hideIncomingTransfers}) {
  final groups = <DayGroup>[];
  for (final transaction in transactions) {
    if (hideIncomingTransfers && transaction.kind == TransactionKind.transfer && transaction.amountCents > 0) {
      final outgoingVisible = transactions.any(
        (other) => other.transferGroupId == transaction.transferGroupId && other.id != transaction.id,
      );
      if (outgoingVisible) continue;
    }
    if (groups.isEmpty || groups.last.date != transaction.date) groups.add(DayGroup(transaction.date));
    final group = groups.last..items.add(transaction);
    if (transaction.kind != TransactionKind.transfer) group.total += transaction.amountCents;
  }
  return groups;
}

final transactionListProvider = AsyncNotifierProvider.family<TransactionList, TransactionListState, TransactionFilters>(
  TransactionList.new,
);

class TransactionList extends AsyncNotifier<TransactionListState> {
  TransactionList(this.filters);

  final TransactionFilters filters;

  Future<Query> _query() async {
    final needsCurrent = filters.periodScope == PeriodScope.current;
    final current = needsCurrent ? (await ref.watch(periodsProvider.future)).current?.id : null;
    return filters.toApiQuery(current);
  }

  @override
  Future<TransactionListState> build() async {
    ref.watchFinance(const [FinanceScope.transactions]);
    final api = ref.watch(financeApiProvider);
    final query = await _query();
    final (page, pending) = await (
      api.transactions(query, perPage: transactionsPageSize),
      api
          .transactions({...query, 'status': TransactionStatus.pending.api}, perPage: 1)
          .then<TransactionPage?>((page) => page, onError: (_) => null),
    ).wait;
    return TransactionListState(
      items: page.data,
      totals: page.totals,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      pendingCount: pending?.totals.count,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || state.isLoading) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(financeApiProvider)
          .transactions(await _query(), cursor: current.nextCursor, perPage: transactionsPageSize);
      final known = {for (final item in current.items) item.id};
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.data.where((item) => !known.contains(item.id))],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (error) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}
