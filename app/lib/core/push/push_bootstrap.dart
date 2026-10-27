import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../notifications/notification_route.dart';
import '../notifications/notifications_api.dart';
import '../notifications/notifications_providers.dart';
import '../router/router.dart';
import 'push_controller.dart';
import 'push_platform.dart';

final pushBootstrapProvider = Provider<void>((ref) {
  final platform = ref.watch(pushPlatformProvider);
  final controller = ref.read(pushControllerProvider.notifier);
  PushTap? waiting;

  bool signedIn() => ref.read(authControllerProvider) is SignedIn;

  Future<void> markRead(String id) async {
    try {
      await ref.read(notificationsApiProvider).markRead(ids: [id]);
      await ref.read(unreadNotificationsCountProvider.notifier).refresh();
    } catch (_) {
      return;
    }
  }

  void go(PushTap tap) {
    if (tap.notificationId case final id?) markRead(id).ignore();
    ref.read(routerProvider).go(nativeNotificationRoute(tap.url) ?? Routes.notifications);
  }

  void open(PushTap tap) {
    if (signedIn()) {
      go(tap);
    } else {
      waiting = tap;
    }
  }

  final taps = platform.taps.listen(open);
  platform.launchTap().then((tap) {
    if (tap != null) open(tap);
  }, onError: (Object _) {});

  ref.listen(authControllerProvider, (previous, next) {
    if (next is SignedIn && previous is! SignedIn) {
      controller.activate().ignore();
      final tap = waiting;
      if (tap != null) {
        waiting = null;
        go(tap);
      }
    }
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (signedIn()) controller.activate().ignore();
    },
  );

  ref.onDispose(() {
    taps.cancel();
    lifecycle.dispose();
  });
});
