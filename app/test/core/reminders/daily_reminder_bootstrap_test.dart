import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/reminders/daily_reminder_bootstrap.dart';
import 'package:carli/core/reminders/daily_reminder_controller.dart';
import 'package:carli/core/reminders/pending_count_reader.dart';
import 'package:carli/core/reminders/reminder_scheduler.dart';

import '../../support/fake_reminder_scheduler.dart';

late FixedAuthController auth;

ProviderContainer bootstrapContainer(
  FakeReminderScheduler scheduler, {
  AuthState initialAuth = const SignedIn(null),
  PendingCountReader? pending,
}) {
  final container = ProviderContainer.test(
    overrides: [
      authControllerProvider.overrideWith(() => auth = FixedAuthController(initialAuth)),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderClockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 21)),
      if (pending != null) pendingCountReaderProvider.overrideWithValue(pending),
    ],
  );
  container.read(dailyReminderBootstrapProvider);
  return container;
}

Future<void> settle(WidgetTester tester) => tester.runAsync(() => Future<void>.delayed(Duration.zero));

void backgroundAndResume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('schedules on launch and reschedules with a fresh count every time the app resumes', (tester) async {
    final scheduler = FakeReminderScheduler();
    var pending = 4;
    bootstrapContainer(scheduler, pending: () async => pending);
    await settle(tester);

    expect(scheduler.permissionRequests, 1);
    expect(scheduler.lastScheduled?.$1, DateTime(2026, 10, 27, 20));
    expect(scheduler.lastScheduled?.$2.body, 'Tienes 4 elementos por revisar');

    pending = 1;
    backgroundAndResume(tester);
    await settle(tester);

    expect(scheduler.scheduled, hasLength(2));
    expect(scheduler.lastScheduled?.$2.body, 'Tienes 1 elemento por revisar');
    expect(scheduler.permissionRequests, 1);
  });

  testWidgets('waits for sign in before asking permission and cancels on sign out', (tester) async {
    final scheduler = FakeReminderScheduler();
    bootstrapContainer(scheduler, initialAuth: const AuthUnknown());
    await settle(tester);

    backgroundAndResume(tester);
    await settle(tester);
    expect(scheduler.permissionRequests, 0);
    expect(scheduler.scheduled, isEmpty);

    auth.emit(const SignedIn(null));
    await settle(tester);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled, hasLength(1));

    auth.emit(const SignedOut());
    await settle(tester);
    expect(scheduler.cancellations, 1);
  });

  testWidgets('reports taps on the reminder so the app can open the pending inbox', (tester) async {
    final scheduler = FakeReminderScheduler(permitted: true);
    final container = bootstrapContainer(scheduler);
    await settle(tester);

    scheduler.tap();
    await settle(tester);

    expect(container.read(reminderTapsProvider), 1);
  });

  testWidgets('a launch from the reminder is delivered once the user is signed in', (tester) async {
    final scheduler = FakeReminderScheduler(permitted: true, launchedFromTap: true);
    final container = bootstrapContainer(scheduler, initialAuth: const AuthUnknown());
    final taps = <int>[];
    container.listen(reminderTapsProvider, (_, next) => taps.add(next));
    await settle(tester);
    expect(taps, isEmpty);

    auth.emit(const SignedIn(null));
    await settle(tester);

    expect(taps, [1]);
  });
}
