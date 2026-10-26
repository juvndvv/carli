import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification.dart';
import 'notifications_api.dart';

const recentNotificationsLimit = 3;

@immutable
class NotificationsState {
  const NotificationsState({required this.items, required this.nextPage, this.loadingMore = false});

  final List<AppNotification> items;
  final int? nextPage;
  final bool loadingMore;

  bool get hasMore => nextPage != null;

  List<AppNotification> get recent => items.take(recentNotificationsLimit).toList();

  NotificationsState withItems(List<AppNotification> items) =>
      NotificationsState(items: items, nextPage: nextPage, loadingMore: loadingMore);

  NotificationsState withLoadingMore(bool loadingMore) =>
      NotificationsState(items: items, nextPage: nextPage, loadingMore: loadingMore);
}

final notificationsProvider = AsyncNotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);

class NotificationsController extends AsyncNotifier<NotificationsState> {
  NotificationsApi get _api => ref.read(notificationsApiProvider);

  UnreadNotificationsCount get _counter => ref.read(unreadNotificationsCountProvider.notifier);

  @override
  Future<NotificationsState> build() async {
    final page = await ref.watch(notificationsApiProvider).page(1);
    _counter.adopt(page.unreadCount);
    return NotificationsState(items: page.items, nextPage: page.nextPage);
  }

  Future<void> refresh() async {
    try {
      final page = await _api.page(1);
      if (!ref.mounted) return;
      _counter.adopt(page.unreadCount);
      state = AsyncData(NotificationsState(items: page.items, nextPage: page.nextPage));
    } catch (error, stackTrace) {
      if (ref.mounted && !state.hasValue) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    final pageNumber = current?.nextPage;
    if (current == null || pageNumber == null || current.loadingMore || state.isLoading) return;
    state = AsyncData(current.withLoadingMore(true));
    try {
      final page = await _api.page(pageNumber);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final known = {for (final item in latest.items) item.id};
      _counter.adopt(page.unreadCount);
      state = AsyncData(
        NotificationsState(
          items: [...latest.items, ...page.items.where((item) => !known.contains(item.id))],
          nextPage: page.nextPage,
        ),
      );
    } catch (_) {
      if (ref.mounted) state = AsyncData((state.value ?? current).withLoadingMore(false));
      rethrow;
    }
  }

  Future<void> markRead(Iterable<String> ids) => _markRead(ids.toSet());

  Future<void> markAllRead() => _markRead(null);

  Future<void> _markRead(Set<String>? targets) async {
    bool targeted(AppNotification item) => item.unread && (targets == null || targets.contains(item.id));

    final counter = _counter;
    final previousCount = counter.current;
    final items = state.value?.items ?? const <AppNotification>[];
    final reverted = {for (final item in items.where(targeted)) item.id: item};
    final now = DateTime.now();

    if (state.value case final current?) {
      state = AsyncData(current.withItems([for (final item in items) targeted(item) ? item.markedRead(now) : item]));
    }
    counter.adopt(targets == null ? 0 : max(0, previousCount - reverted.length));

    try {
      final remaining = await _api.markRead(ids: targets?.toList());
      if (ref.mounted) counter.adopt(remaining);
    } catch (_) {
      if (!ref.mounted) rethrow;
      if (state.value case final current?) {
        state = AsyncData(current.withItems([for (final item in current.items) reverted[item.id] ?? item]));
      }
      counter.adopt(previousCount);
      rethrow;
    }
  }
}

final unreadNotificationsCountProvider = AsyncNotifierProvider<UnreadNotificationsCount, int>(
  UnreadNotificationsCount.new,
);

class UnreadNotificationsCount extends AsyncNotifier<int> {
  @override
  Future<int> build() => ref.watch(notificationsApiProvider).unreadCount();

  int get current => state.value ?? 0;

  void adopt(int count) => state = AsyncData(count);

  Future<void> refresh() async {
    if (ref.exists(notificationsProvider)) {
      await ref.read(notificationsProvider.notifier).refresh();
      return;
    }
    try {
      final count = await ref.read(notificationsApiProvider).unreadCount();
      if (ref.mounted) adopt(count);
    } catch (_) {
      return;
    }
  }
}
