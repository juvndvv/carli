import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notifications_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/button.dart';
import '../../ui/card.dart';
import '../../ui/skeleton.dart';
import 'notification_list.dart';
import 'unread_dot.dart';

class NotificationsHomeCard extends ConsumerWidget {
  const NotificationsHomeCard({super.key, this.onSeeAll, this.now});

  final VoidCallback? onSeeAll;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifications = ref.watch(notificationsProvider);

    final body = switch (notifications) {
      AsyncValue(hasValue: true, :final value) => NotificationList(items: value!.recent, now: now),
      AsyncValue(hasError: true) => Padding(
        padding: const EdgeInsets.all(CarliSpace.s16),
        child: Text(
          'No se han podido cargar las notificaciones.',
          textAlign: TextAlign.center,
          style: CarliType.small.copyWith(color: colors.text3),
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(CarliSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: CarliSpace.s8,
          children: [CarliSkeleton(width: 200, height: 14), CarliSkeleton(width: 140, height: 12)],
        ),
      ),
    };

    return CarliCard(
      padding: const EdgeInsets.only(top: CarliSpace.s12, bottom: CarliSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
            child: Row(
              spacing: CarliSpace.s8,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Notificaciones recientes', style: CarliType.h2.copyWith(color: colors.text)),
                  ),
                ),
                CarliButton(
                  label: 'Ver todas',
                  variant: CarliButtonVariant.ghost,
                  size: CarliButtonSize.sm,
                  block: false,
                  onPressed: onSeeAll ?? () => context.push(notificationsRoute),
                ),
              ],
            ),
          ),
          body,
        ],
      ),
    );
  }
}
