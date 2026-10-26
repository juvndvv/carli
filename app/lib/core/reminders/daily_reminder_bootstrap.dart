import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'daily_reminder_controller.dart';
import 'reminder_scheduler.dart';

final dailyReminderBootstrapProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final controller = ref.read(dailyReminderProvider.notifier);
  var tapWaitingForSignIn = false;

  bool signedIn() => ref.read(authControllerProvider) is SignedIn;

  void openPending() {
    if (signedIn()) {
      ref.read(reminderTapsProvider.notifier).record();
    } else {
      tapWaitingForSignIn = true;
    }
  }

  final taps = scheduler.taps.listen((_) => openPending());
  scheduler.launchedFromReminder().then((launched) {
    if (launched) openPending();
  }, onError: (Object _) {});

  ref.listen(authControllerProvider, (previous, next) {
    if (next is SignedIn && previous is! SignedIn) {
      controller.activate().ignore();
      if (tapWaitingForSignIn) {
        tapWaitingForSignIn = false;
        scheduleMicrotask(() => ref.read(reminderTapsProvider.notifier).record());
      }
    } else if (next is SignedOut && previous is! SignedOut) {
      controller.deactivate().ignore();
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
