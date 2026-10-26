import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_settings.dart';

final reminderStoreProvider = Provider<ReminderStore>((ref) => ReminderStore());

class ReminderStore {
  static const _enabledKey = 'daily_reminder.enabled';
  static const _hourKey = 'daily_reminder.hour';
  static const _minuteKey = 'daily_reminder.minute';
  static const _permissionRequestedKey = 'daily_reminder.permission_requested';

  Future<ReminderSettings> read() async {
    final preferences = await SharedPreferences.getInstance();
    const defaults = ReminderSettings();
    final hour = preferences.getInt(_hourKey);
    final minute = preferences.getInt(_minuteKey);
    final validTime = hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60;
    return ReminderSettings(
      enabled: preferences.getBool(_enabledKey) ?? defaults.enabled,
      time: validTime ? ReminderTime(hour, minute) : defaults.time,
      permissionRequested: preferences.getBool(_permissionRequestedKey) ?? defaults.permissionRequested,
    );
  }

  Future<void> write(ReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setBool(_enabledKey, settings.enabled),
      preferences.setInt(_hourKey, settings.time.hour),
      preferences.setInt(_minuteKey, settings.time.minute),
      preferences.setBool(_permissionRequestedKey, settings.permissionRequested),
    ]);
  }
}
