import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pending_count_reader.dart';
import 'reminder_message.dart';
import 'reminder_scheduler.dart';
import 'reminder_settings.dart';
import 'reminder_store.dart';

enum ReminderPermission { granted, denied, notDetermined }

@immutable
class DailyReminderState {
  const DailyReminderState({required this.settings, required this.permission});

  final ReminderSettings settings;
  final ReminderPermission permission;

  bool get blocked => settings.enabled && permission == ReminderPermission.denied;

  bool get active => settings.enabled && permission == ReminderPermission.granted;

  DailyReminderState copyWith({ReminderSettings? settings, ReminderPermission? permission}) =>
      DailyReminderState(settings: settings ?? this.settings, permission: permission ?? this.permission);
}

final reminderClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final dailyReminderProvider = AsyncNotifierProvider<DailyReminderController, DailyReminderState>(
  DailyReminderController.new,
);

class DailyReminderController extends AsyncNotifier<DailyReminderState> {
  Future<void> _tail = Future.value();

  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);
  ReminderStore get _store => ref.read(reminderStoreProvider);

  @override
  Future<DailyReminderState> build() async {
    final settings = await _store.read();
    return DailyReminderState(settings: settings, permission: await _permissionFor(settings));
  }

  Future<void> activate() => _serialized(() async {
    final current = await future;
    final ready = current.settings.enabled && !current.settings.permissionRequested
        ? await _requestPermission(current)
        : await _refreshPermission(current);
    await _apply(ready);
  });

  Future<void> deactivate() => _serialized(() => _scheduler.cancel());

  Future<void> reschedule() => _serialized(() async => _apply(await future));

  Future<void> setEnabled(bool enabled) => _serialized(() async {
    final current = await future;
    final saved = await _save(current.copyWith(settings: current.settings.copyWith(enabled: enabled)));
    final ready = enabled && saved.permission != ReminderPermission.granted ? await _requestPermission(saved) : saved;
    await _apply(ready);
  });

  Future<void> setTime(ReminderTime time) => _serialized(() async {
    final current = await future;
    await _apply(await _save(current.copyWith(settings: current.settings.copyWith(time: time))));
  });

  Future<bool> sendTest() async {
    var current = await future;
    if (current.permission != ReminderPermission.granted) current = await _requestPermission(current);
    if (current.permission != ReminderPermission.granted) return false;
    await _scheduler.showNow(await _message());
    return true;
  }

  Future<void> _serialized(Future<void> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<ReminderPermission> _permissionFor(ReminderSettings settings) async {
    if (await _scheduler.isPermitted()) return ReminderPermission.granted;
    return settings.permissionRequested ? ReminderPermission.denied : ReminderPermission.notDetermined;
  }

  Future<DailyReminderState> _refreshPermission(DailyReminderState current) async {
    final next = current.copyWith(permission: await _permissionFor(current.settings));
    state = AsyncData(next);
    return next;
  }

  Future<DailyReminderState> _requestPermission(DailyReminderState current) async {
    final granted = await _scheduler.requestPermission();
    final settings = current.settings.copyWith(permissionRequested: true);
    await _store.write(settings);
    final permission = granted || await _scheduler.isPermitted()
        ? ReminderPermission.granted
        : ReminderPermission.denied;
    final next = DailyReminderState(settings: settings, permission: permission);
    state = AsyncData(next);
    return next;
  }

  Future<DailyReminderState> _save(DailyReminderState next) async {
    await _store.write(next.settings);
    state = AsyncData(next);
    return next;
  }

  Future<void> _apply(DailyReminderState current) async {
    if (!current.active) return _scheduler.cancel();
    final now = ref.read(reminderClockProvider)();
    await _scheduler.scheduleDaily(current.settings.time.nextAfter(now), await _message());
  }

  Future<ReminderMessage> _message() async {
    try {
      return reminderMessageFor(await ref.read(pendingCountReaderProvider)());
    } on Object {
      return reminderMessageFor(null);
    }
  }
}

final reminderTapsProvider = NotifierProvider<ReminderTaps, int>(ReminderTaps.new);

class ReminderTaps extends Notifier<int> {
  @override
  int build() => 0;

  void record() => state++;
}
