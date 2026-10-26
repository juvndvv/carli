import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification.dart';
import '../../core/notifications/notification_route.dart';
import '../../core/notifications/notifications_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/pressable.dart';
import '../../ui/toast.dart';
import 'time_ago.dart';
import 'unread_dot.dart';

const _typeIcons = {
  'budget': 'triangle-alert',
  'recurring': 'bell',
  'pending': 'clock',
  'goal': 'target',
  'debt': 'hand-coins',
  'summary': 'chart-column',
  'period': 'calendar',
  'upcoming': 'repeat',
  'payroll': 'wallet',
  'test': 'bell',
};

String notificationIcon(AppNotification notification) {
  final type = notification.type.toLowerCase();
  for (final MapEntry(:key, :value) in _typeIcons.entries) {
    if (type.contains(key)) return value;
  }
  return 'bell';
}

String notificationSubtitle(AppNotification notification, {DateTime? now}) {
  final timeAgo = formatTimeAgo(notification.createdAt, now: now);
  final body = notification.body;
  return body == null || body.isEmpty ? timeAgo : '$body · $timeAgo';
}

const markReadErrorMessage = 'No se han podido marcar como leídas.';

void openNotification(BuildContext context, WidgetRef ref, AppNotification notification) {
  if (notification.unread) {
    final toasts = ref.read(toastControllerProvider.notifier);
    unawaited(
      ref.read(notificationsProvider.notifier).markRead([notification.id]).catchError((_) {
        toasts.error(markReadErrorMessage);
      }),
    );
  }
  if (nativeNotificationRoute(notification.url) case final route?) {
    context.push(route);
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, required this.onTap, this.now});

  final AppNotification notification;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                child: CarliIcon(carliIconNamed(notificationIcon(notification)), size: 18, color: colors.text2),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: CarliType.body.copyWith(
                        color: colors.text,
                        fontWeight: notification.unread ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      notificationSubtitle(notification, now: now),
                      style: CarliType.small.copyWith(color: colors.text3),
                    ),
                  ],
                ),
              ),
              if (notification.unread) const UnreadDot(),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationList extends ConsumerWidget {
  const NotificationList({super.key, required this.items, this.now});

  final List<AppNotification> items;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s16),
        child: Text(
          'No tienes notificaciones.',
          textAlign: TextAlign.center,
          style: CarliType.small.copyWith(color: colors.text3),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, notification) in items.indexed) ...[
          if (index > 0) Divider(height: 1, indent: 64, color: colors.border),
          NotificationTile(
            key: ValueKey(notification.id),
            notification: notification,
            now: now,
            onTap: () => openNotification(context, ref, notification),
          ),
        ],
      ],
    );
  }
}
