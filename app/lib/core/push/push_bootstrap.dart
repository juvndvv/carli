import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../notifications/notification_route.dart';
import '../router/router.dart';
import 'push_controller.dart';
import 'push_platform.dart';

final pushBootstrapProvider = Provider<void>((ref) {
  final platform = ref.watch(pushPlatformProvider);
  final controller = ref.read(pushControllerProvider.notifier);
  String? waiting;

  bool signedIn() => ref.read(authControllerProvider) is SignedIn;

  void open(PushTap tap) {
    final location = nativeNotificationRoute(tap.url) ?? Routes.notifications;
    if (signedIn()) {
      ref.read(routerProvider).go(location);
    } else {
      waiting = location;
    }
  }

  final taps = platform.taps.listen(open);
  platform.launchTap().then((tap) {
    if (tap != null) open(tap);
  }, onError: (Object _) {});

  ref.listen(authControllerProvider, (previous, next) {
    if (next is SignedIn && previous is! SignedIn) {
      controller.activate().ignore();
      final location = waiting;
      if (location != null) {
        waiting = null;
        ref.read(routerProvider).go(location);
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
