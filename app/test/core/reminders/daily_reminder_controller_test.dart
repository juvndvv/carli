import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/reminders/daily_reminder_controller.dart';
import 'package:carli/core/reminders/pending_count_reader.dart';
import 'package:carli/core/reminders/reminder_message.dart';
import 'package:carli/core/reminders/reminder_scheduler.dart';
import 'package:carli/core/reminders/reminder_settings.dart';
import 'package:carli/core/reminders/reminder_store.dart';

import '../../support/fake_reminder_scheduler.dart';

final now = DateTime(2026, 10, 26, 10);

ProviderContainer reminderContainer(FakeReminderScheduler scheduler, {PendingCountReader? pending}) {
  return ProviderContainer.test(
    overrides: [
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderClockProvider.overrideWithValue(() => now),
      if (pending != null) pendingCountReaderProvider.overrideWithValue(pending),
    ],
  );
}

DailyReminderController controllerOf(ProviderContainer container) => container.read(dailyReminderProvider.notifier);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('asks for permission on the first activation and schedules the next 20:00 with the pending count', () async {
    final scheduler = FakeReminderScheduler();
    final container = reminderContainer(scheduler, pending: () async => 3);

    await controllerOf(container).activate();

    expect(scheduler.permissionRequests, 1);
    expect(scheduler.lastScheduled, (DateTime(2026, 10, 26, 20), reminderMessageFor(3)));
    final state = container.read(dailyReminderProvider).value!;
    expect(state.permission, ReminderPermission.granted);
    expect(state.settings.permissionRequested, isTrue);
    expect((await ReminderStore().read()).permissionRequested, isTrue);
  });

  test('does not ask again on later activations and refreshes the text each time', () async {
    final scheduler = FakeReminderScheduler();
    var pending = 2;
    final container = reminderContainer(scheduler, pending: () async => pending);

    await controllerOf(container).activate();
    pending = 0;
    await controllerOf(container).activate();

    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled.map((entry) => entry.$2.body), [
      'Tienes 2 elementos por revisar',
      'Repasa tus movimientos de hoy',
    ]);
  });

  test('uses the generic text when no pending reader is wired or it fails', () async {
    final scheduler = FakeReminderScheduler(permitted: true);
    await controllerOf(reminderContainer(scheduler)).activate();
    await controllerOf(reminderContainer(scheduler, pending: () => Future.error(StateError('offline')))).activate();

    expect(scheduler.scheduled.map((entry) => entry.$2.body), everyElement('Repasa tus movimientos de hoy'));
  });

  test('cancels and reports the denial when permission is refused', () async {
    final scheduler = FakeReminderScheduler(grantOnRequest: false);
    final container = reminderContainer(scheduler);

    await controllerOf(container).activate();

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancellations, 1);
    final state = container.read(dailyReminderProvider).value!;
    expect(state.permission, ReminderPermission.denied);
    expect(state.blocked, isTrue);
  });

  test('picks up a permission granted later from iOS Settings', () async {
    SharedPreferences.setMockInitialValues({'daily_reminder.permission_requested': true});
    final scheduler = FakeReminderScheduler();
    final container = reminderContainer(scheduler);
    expect((await container.read(dailyReminderProvider.future)).permission, ReminderPermission.denied);

    scheduler.permitted = true;
    await controllerOf(container).activate();

    expect(scheduler.permissionRequests, 0);
    expect(container.read(dailyReminderProvider).value!.permission, ReminderPermission.granted);
    expect(scheduler.lastScheduled?.$1, DateTime(2026, 10, 26, 20));
  });

  test('turning the reminder off cancels it and turning it on asks for permission', () async {
    final scheduler = FakeReminderScheduler();
    final container = reminderContainer(scheduler);

    await controllerOf(container).setEnabled(false);
    expect(scheduler.cancellations, 1);
    expect(scheduler.permissionRequests, 0);
    expect((await ReminderStore().read()).enabled, isFalse);

    await controllerOf(container).setEnabled(true);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled, hasLength(1));
    expect((await ReminderStore().read()).enabled, isTrue);
  });

  test('changing the time persists it and reschedules', () async {
    final scheduler = FakeReminderScheduler(permitted: true);
    final container = reminderContainer(scheduler);

    await controllerOf(container).setTime(const ReminderTime(8, 30));

    expect(scheduler.lastScheduled?.$1, DateTime(2026, 10, 27, 8, 30));
    expect((await ReminderStore().read()).time, const ReminderTime(8, 30));
  });

  test('the test reminder fires immediately with the current text', () async {
    final scheduler = FakeReminderScheduler(permitted: true);
    final container = reminderContainer(scheduler, pending: () async => 5);

    expect(await controllerOf(container).sendTest(), isTrue);
    expect(scheduler.shown, [reminderMessageFor(5)]);
  });

  test('the test reminder is not sent without permission', () async {
    final scheduler = FakeReminderScheduler(grantOnRequest: false);

    expect(await controllerOf(reminderContainer(scheduler)).sendTest(), isFalse);
    expect(scheduler.shown, isEmpty);
  });
}
