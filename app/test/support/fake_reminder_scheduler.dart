import 'dart:async';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/reminders/reminder_message.dart';
import 'package:carli/core/reminders/reminder_scheduler.dart';

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.permitted = false, this.grantOnRequest = true, this.launchedFromTap = false});

  bool permitted;
  bool grantOnRequest;
  bool launchedFromTap;
  int permissionRequests = 0;
  int cancellations = 0;
  final scheduled = <(DateTime, ReminderMessage)>[];
  final shown = <ReminderMessage>[];
  final _taps = StreamController<void>.broadcast();

  (DateTime, ReminderMessage)? get lastScheduled => scheduled.isEmpty ? null : scheduled.last;

  void tap() => _taps.add(null);

  @override
  Stream<void> get taps => _taps.stream;

  @override
  Future<bool> launchedFromReminder() async => launchedFromTap;

  @override
  Future<bool> isPermitted() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permitted = permitted || grantOnRequest;
    return permitted;
  }

  @override
  Future<void> scheduleDaily(DateTime firstAt, ReminderMessage message) async => scheduled.add((firstAt, message));

  @override
  Future<void> showNow(ReminderMessage message) async => shown.add(message);

  @override
  Future<void> cancel() async => cancellations++;
}

class FixedAuthController extends AuthController {
  FixedAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void emit(AuthState next) => state = next;
}
