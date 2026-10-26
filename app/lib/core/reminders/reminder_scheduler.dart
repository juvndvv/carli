import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_reminder_scheduler.dart';
import 'reminder_message.dart';

abstract interface class ReminderScheduler {
  Stream<void> get taps;

  Future<bool> launchedFromReminder();

  Future<bool> isPermitted();

  Future<bool> requestPermission();

  Future<void> scheduleDaily(DateTime firstAt, ReminderMessage message);

  Future<void> showNow(ReminderMessage message);

  Future<void> cancel();
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = LocalReminderScheduler();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
