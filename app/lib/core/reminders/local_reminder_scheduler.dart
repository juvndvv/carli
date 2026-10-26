import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_message.dart';
import 'reminder_scheduler.dart';

class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _dailyId = 2000;
  static const _testId = 2001;
  static const _payload = 'pending';
  static const _details = NotificationDetails(iOS: DarwinNotificationDetails(threadIdentifier: 'daily_reminder'));

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<void>.broadcast();
  Future<void>? _ready;

  @override
  Stream<void> get taps => _taps.stream;

  Future<void> _ensureReady() => _ready ??= _initialize();

  Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) _taps.add(null);
      },
    );
  }

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> launchedFromReminder() async {
    await _ensureReady();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true && details?.notificationResponse?.payload == _payload;
  }

  @override
  Future<bool> isPermitted() async {
    await _ensureReady();
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();
    return await _ios?.requestPermissions(alert: true, sound: true, badge: true) ?? false;
  }

  @override
  Future<void> scheduleDaily(DateTime firstAt, ReminderMessage message) async {
    await _ensureReady();
    await _plugin.cancel(id: _dailyId);
    await _plugin.zonedSchedule(
      id: _dailyId,
      scheduledDate: tz.TZDateTime(tz.local, firstAt.year, firstAt.month, firstAt.day, firstAt.hour, firstAt.minute),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: message.title,
      body: message.body,
      payload: _payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> showNow(ReminderMessage message) async {
    await _ensureReady();
    await _plugin.show(
      id: _testId,
      title: message.title,
      body: message.body,
      notificationDetails: _details,
      payload: _payload,
    );
  }

  @override
  Future<void> cancel() async {
    await _ensureReady();
    await _plugin.cancel(id: _dailyId);
  }

  void dispose() => _taps.close();
}
