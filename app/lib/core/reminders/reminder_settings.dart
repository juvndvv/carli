import 'package:flutter/foundation.dart';

@immutable
class ReminderTime {
  const ReminderTime(this.hour, this.minute) : assert(hour >= 0 && hour < 24), assert(minute >= 0 && minute < 60);

  static const evening = ReminderTime(20, 0);

  final int hour;
  final int minute;

  String get label => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DateTime nextAfter(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  @override
  bool operator ==(Object other) => other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => label;
}

@immutable
class ReminderSettings {
  const ReminderSettings({this.enabled = true, this.time = ReminderTime.evening, this.permissionRequested = false});

  final bool enabled;
  final ReminderTime time;
  final bool permissionRequested;

  ReminderSettings copyWith({bool? enabled, ReminderTime? time, bool? permissionRequested}) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    time: time ?? this.time,
    permissionRequested: permissionRequested ?? this.permissionRequested,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.time == time &&
      other.permissionRequested == permissionRequested;

  @override
  int get hashCode => Object.hash(enabled, time, permissionRequested);
}
