import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/reminders/reminder_settings.dart';
import 'package:carli/core/reminders/reminder_store.dart';

void main() {
  group('next occurrence', () {
    test('is today at 20:00 when it is still earlier', () {
      expect(ReminderTime.evening.nextAfter(DateTime(2026, 10, 26, 9, 15)), DateTime(2026, 10, 26, 20));
    });

    test('is tomorrow once 20:00 has arrived or passed', () {
      expect(ReminderTime.evening.nextAfter(DateTime(2026, 10, 26, 20)), DateTime(2026, 10, 27, 20));
      expect(ReminderTime.evening.nextAfter(DateTime(2026, 10, 26, 22, 30)), DateTime(2026, 10, 27, 20));
    });

    test('rolls over months and years', () {
      expect(ReminderTime.evening.nextAfter(DateTime(2026, 10, 31, 21)), DateTime(2026, 11, 1, 20));
      expect(ReminderTime.evening.nextAfter(DateTime(2026, 12, 31, 23, 59)), DateTime(2027, 1, 1, 20));
    });

    test('honours a custom time', () {
      expect(const ReminderTime(7, 45).nextAfter(DateTime(2026, 10, 26, 7, 44)), DateTime(2026, 10, 26, 7, 45));
      expect(const ReminderTime(7, 45).label, '07:45');
    });
  });

  group('store', () {
    test('defaults to an enabled reminder at 20:00 without asking permission yet', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = await ReminderStore().read();

      expect(settings, const ReminderSettings(enabled: true, time: ReminderTime(20, 0), permissionRequested: false));
    });

    test('persists the settings', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReminderStore();
      const saved = ReminderSettings(enabled: false, time: ReminderTime(21, 30), permissionRequested: true);

      await store.write(saved);

      expect(await store.read(), saved);
    });

    test('ignores an invalid stored time', () async {
      SharedPreferences.setMockInitialValues({'daily_reminder.hour': 31, 'daily_reminder.minute': 0});

      expect((await ReminderStore().read()).time, ReminderTime.evening);
    });
  });
}
