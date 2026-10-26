import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notifications_providers.dart';
import '../../core/theme/tokens.dart';
import '../../ui/button.dart';
import '../../ui/icon_names.dart';

const notificationsRoute = '/notificaciones';

class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, this.size = 8, this.outlined = false, this.semanticLabel = 'Sin leer'});

  final double size;
  final bool outlined;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: colors.bg, width: 2) : null,
      ),
    );
    return semanticLabel == null ? ExcludeSemantics(child: dot) : Semantics(label: semanticLabel, child: dot);
  }
}

String notificationsBellLabel(int unread) => unread > 0 ? 'Notificaciones ($unread sin leer)' : 'Notificaciones';

class NotificationsBellButton extends ConsumerWidget {
  const NotificationsBellButton({super.key, this.onPressed, this.size = CarliButtonSize.sm});

  final VoidCallback? onPressed;
  final CarliButtonSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CarliButton.icon(
          icon: carliIconNamed('bell'),
          semanticLabel: notificationsBellLabel(unread),
          size: size,
          onPressed: onPressed ?? () => context.push(notificationsRoute),
        ),
        if (unread > 0)
          const Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(child: UnreadDot(size: 12, outlined: true, semanticLabel: null)),
          ),
      ],
    );
  }
}
