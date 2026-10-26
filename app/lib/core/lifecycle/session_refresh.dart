import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../notifications/notifications_providers.dart';
import '../pending/pending_providers.dart';

final sessionRefreshProvider = Provider<void>((ref) {
  bool signedIn() => ref.read(authControllerProvider) is SignedIn;

  void refresh() {
    if (!signedIn()) return;
    ref.read(pendingSummaryProvider.notifier).refreshIfStale().ignore();
    ref.read(unreadNotificationsCountProvider.notifier).refresh().ignore();
  }

  final listener = AppLifecycleListener(onResume: refresh);
  ref.onDispose(listener.dispose);

  ref.listen(authControllerProvider, (previous, next) {
    if (next is SignedIn && previous is! SignedIn) refresh();
    if (next is SignedOut && previous is SignedIn) {
      ref.invalidate(pendingSummaryProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }
  });
});
