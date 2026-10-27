import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/finance/data/finance_changes.dart';
import '../api/api_client.dart';
import '../api/api_error.dart';
import 'pending_models.dart';

const pendingStaleAfter = Duration(seconds: 30);
const pendingRefreshDelay = Duration(milliseconds: 300);
const pendingFinanceScopes = [FinanceScope.transactions, FinanceScope.recurring];
const pendingListErrorMessage = 'Comprueba tu conexión e inténtalo de nuevo.';
const pendingLoadMoreErrorMessage = 'No se han podido cargar más pendientes.';

final pendingApiProvider = Provider<PendingApi>((ref) => PendingApi(ref.watch(dioProvider)));

class PendingApi {
  PendingApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/pending';

  Future<PendingSummary> summary() async {
    final response = await _dio.get<PendingJson>('$_base/summary');
    return PendingSummary.fromJson(response.data!['data'] as PendingJson);
  }

  Future<PendingPage> page(PendingFilter filter, {String? cursor}) async {
    final response = await _dio.get<PendingJson>(
      _base,
      queryParameters: {'module': ?filter.module, 'type': ?filter.type, 'cursor': ?cursor},
    );
    return PendingPage.fromJson(response.data!);
  }
}

final pendingSummaryProvider = AsyncNotifierProvider<PendingSummaryController, PendingSummary>(
  PendingSummaryController.new,
);

final pendingTotalProvider = Provider<int>((ref) => ref.watch(pendingSummaryProvider).value?.total ?? 0);

final pendingEntriesProvider = Provider<List<PendingSummaryEntry>>(
  (ref) => ref.watch(pendingSummaryProvider).value?.entries ?? const [],
);

class PendingSummaryController extends AsyncNotifier<PendingSummary> {
  Timer? _refreshTimer;
  DateTime? _fetchedAt;

  @override
  Future<PendingSummary> build() async {
    ref.watchFinance(pendingFinanceScopes);
    ref.onDispose(() => _refreshTimer?.cancel());
    final summary = await ref.watch(pendingApiProvider).summary();
    _fetchedAt = DateTime.now();
    return summary;
  }

  Future<PendingSummary?> refresh() async {
    if (state.isLoading) {
      try {
        return await future;
      } on Object {
        return state.value;
      }
    }
    try {
      final summary = await ref.read(pendingApiProvider).summary();
      if (!ref.mounted) return summary;
      _fetchedAt = DateTime.now();
      state = AsyncData(summary);
      return summary;
    } on Object {
      return null;
    }
  }

  Future<PendingSummary?> refreshIfStale({Duration maxAge = pendingStaleAfter}) async {
    final fetchedAt = _fetchedAt;
    final current = state.value;
    if (current != null && fetchedAt != null && DateTime.now().difference(fetchedAt) < maxAge) return current;
    return refresh();
  }

  void resolve(PendingItem item) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.without(item));
    _refreshTimer?.cancel();
    _refreshTimer = Timer(pendingRefreshDelay, () {
      _refreshTimer = null;
      if (ref.mounted) refresh().ignore();
    });
  }
}

@immutable
class PendingListState {
  const PendingListState({required this.items, required this.nextCursor, this.loadingMore = false, this.loadMoreError});

  final List<PendingItem> items;
  final String? nextCursor;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasMore => nextCursor != null;

  PendingListState copyWith({
    List<PendingItem>? items,
    String? Function()? nextCursor,
    bool? loadingMore,
    String? Function()? loadMoreError,
  }) => PendingListState(
    items: items ?? this.items,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError == null ? this.loadMoreError : loadMoreError(),
  );
}

final pendingListProvider = AsyncNotifierProvider.autoDispose.family<PendingList, PendingListState, PendingFilter>(
  PendingList.new,
);

class PendingList extends AsyncNotifier<PendingListState> {
  PendingList(this.filter);

  final PendingFilter filter;

  @override
  Future<PendingListState> build() async {
    ref.watchFinance(pendingFinanceScopes);
    final page = await ref.watch(pendingApiProvider).page(filter);
    return PendingListState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || state.isLoading) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreError: () => null));
    try {
      final page = await ref.read(pendingApiProvider).page(filter, cursor: current.nextCursor);
      final latest = _latestWhileLoadingMore();
      if (latest == null) return;
      final known = {for (final item in latest.items) item.key};
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...page.items.where((item) => !known.contains(item.key))],
          nextCursor: () => page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (error) {
      final latest = _latestWhileLoadingMore();
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          loadingMore: false,
          loadMoreError: () => apiErrorMessage(error, fallback: pendingLoadMoreErrorMessage),
        ),
      );
    }
  }

  PendingListState? _latestWhileLoadingMore() {
    if (!ref.mounted || state.isLoading) return null;
    final latest = state.value;
    return latest != null && latest.loadingMore ? latest : null;
  }

  void resolve(PendingItem item) {
    final current = state.value;
    if (current != null) {
      final remaining = [
        for (final candidate in current.items)
          if (candidate.key != item.key) candidate,
      ];
      final removed = remaining.length < current.items.length;
      state = AsyncData(current.copyWith(items: remaining));
      if (removed && remaining.isEmpty && current.hasMore) loadMore().ignore();
    }
    ref.read(pendingSummaryProvider.notifier).resolve(item);
  }
}
