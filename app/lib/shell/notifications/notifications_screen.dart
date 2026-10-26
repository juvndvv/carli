import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notifications_providers.dart';
import '../../core/theme/tokens.dart';
import '../../ui/async_view.dart';
import '../../ui/button.dart';
import '../../ui/card.dart';
import '../../ui/icon_names.dart';
import '../../ui/page.dart';
import '../../ui/skeleton.dart';
import '../../ui/toast.dart';
import 'notification_list.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    if (ref.read(notificationsProvider).hasValue) {
      Future.microtask(() => ref.read(notificationsProvider.notifier).refresh());
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (_) {
      ref.read(toastControllerProvider.notifier).error(markReadErrorMessage);
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(notificationsProvider.notifier).loadMore();
    } catch (_) {
      ref.read(toastControllerProvider.notifier).error('No se han podido cargar más notificaciones.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return CarliPage(
      title: 'Notificaciones',
      trailing: unread > 0
          ? CarliButton.icon(
              icon: carliIconNamed('check-check'),
              semanticLabel: 'Marcar como leídas',
              size: CarliButtonSize.sm,
              onPressed: _markAllRead,
            )
          : null,
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, 0),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: notifications,
              errorTitle: 'No se han podido cargar las notificaciones',
              onRetry: () => ref.invalidate(notificationsProvider),
              loading: const NotificationsSkeleton(),
              data: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CarliSpace.s16,
                children: [
                  CarliCard(
                    padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
                    child: NotificationList(items: state.items, now: widget.now),
                  ),
                  if (state.hasMore)
                    Center(
                      child: CarliButton(
                        label: 'Cargar más',
                        variant: CarliButtonVariant.ghost,
                        size: CarliButtonSize.md,
                        block: false,
                        loading: state.loadingMore,
                        onPressed: _loadMore,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return CarliCard(
      padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
      child: Column(
        children: [
          for (var index = 0; index < rows; index++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
              child: Row(
                spacing: CarliSpace.s12,
                children: [
                  CarliSkeleton.circle(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: CarliSpace.s4,
                      children: [CarliSkeleton(width: 180, height: 14), CarliSkeleton(width: 120, height: 12)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
