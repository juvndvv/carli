import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification.dart';
import '../../core/notifications/notifications_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/async_view.dart';
import '../../ui/button.dart';
import '../../ui/card.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';
import '../../ui/page.dart';
import '../../ui/sheet.dart';
import '../../ui/skeleton.dart';
import '../../ui/toast.dart';
import 'notification_list.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _DeleteChoice { read, all }

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

  Future<void> _delete({required bool hasRead}) async {
    final choice = await showCarliSheet<_DeleteChoice>(
      context,
      title: 'Borrar notificaciones',
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: CarliSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRead)
              CarliListItem(
                title: 'Borrar leídas',
                icon: carliIconNamed('check-check'),
                onTap: () => Navigator.pop(context, _DeleteChoice.read),
              ),
            CarliListItem(
              title: 'Borrar todas',
              subtitle: 'También las que no has leído',
              icon: carliIconNamed('trash'),
              onTap: () => Navigator.pop(context, _DeleteChoice.all),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _DeleteChoice.all) {
      final confirmed = await confirmCarli(
        context,
        title: '¿Borrar todas las notificaciones?',
        message: 'No se pueden recuperar.',
        confirmLabel: 'Borrar todas',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    final controller = ref.read(notificationsProvider.notifier);
    try {
      await (choice == _DeleteChoice.all ? controller.deleteAll() : controller.deleteRead());
    } catch (_) {
      ref.read(toastControllerProvider.notifier).error(deleteErrorMessage);
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
    final items = notifications.value?.items ?? const <AppNotification>[];
    // Read ones may sit on pages not loaded yet, so offer the option while more remain.
    final hasRead = items.any((item) => !item.unread) || (notifications.value?.hasMore ?? false);

    return CarliPage(
      title: 'Notificaciones',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread > 0)
            CarliButton.icon(
              icon: carliIconNamed('check-check'),
              semanticLabel: 'Marcar como leídas',
              size: CarliButtonSize.sm,
              onPressed: _markAllRead,
            ),
          if (items.isNotEmpty)
            CarliButton.icon(
              icon: carliIconNamed('trash'),
              semanticLabel: 'Borrar notificaciones',
              size: CarliButtonSize.sm,
              onPressed: () => _delete(hasRead: hasRead),
            ),
        ],
      ),
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
                  if (state.items.isEmpty)
                    const CarliCard(
                      padding: EdgeInsets.symmetric(vertical: CarliSpace.s4),
                      child: NotificationList(items: []),
                    )
                  else ...[
                    if (state.items.where((item) => item.unread).toList() case final unreadItems
                        when unreadItems.isNotEmpty)
                      _Group(title: 'Sin leer', items: unreadItems, now: widget.now),
                    if (state.items.where((item) => !item.unread).toList() case final readItems
                        when readItems.isNotEmpty)
                      _Group(title: 'Leídas', items: readItems, now: widget.now),
                    Text(
                      'Desliza para marcar como leída o borrar.',
                      textAlign: TextAlign.center,
                      style: CarliType.small.copyWith(color: context.colors.text3),
                    ),
                  ],
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

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items, this.now});

  final String title;
  final List<AppNotification> items;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s8,
      children: [
        CarliSectionHeader(title: title),
        CarliCard(
          padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
          child: NotificationList(items: items, now: now),
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
