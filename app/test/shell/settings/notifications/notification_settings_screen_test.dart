import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/reminders/daily_reminder_controller.dart';
import 'package:carli/core/reminders/pending_count_reader.dart';
import 'package:carli/core/reminders/reminder_scheduler.dart';
import 'package:carli/core/reminders/reminder_settings.dart';
import 'package:carli/core/reminders/reminder_store.dart';
import 'package:carli/shell/settings/notifications/notification_settings_screen.dart';
import 'package:carli/ui/toast.dart';

import '../../../support/fake_api.dart';
import '../../../support/fake_reminder_scheduler.dart';
import '../../../support/finance_app.dart';

typedef Json = Map<String, dynamic>;

Json typeJson(String type, String label, {bool push = true, bool inApp = true, String? description}) => {
  'type': type,
  'label': label,
  'description': description,
  'push': push,
  'in_app': inApp,
  'default_push': true,
  'default_in_app': true,
};

Json preferencesBody({bool weeklyPush = false}) => {
  'data': [
    {
      'module': 'core',
      'name': 'General',
      'icon': 'inbox',
      'enabled': true,
      'types': [typeJson('pending_digest', 'Pendientes por revisar (diario 20:00)')],
    },
    {
      'module': 'finance',
      'name': 'Finanzas',
      'icon': 'wallet',
      'enabled': true,
      'types': [
        typeJson('budget_threshold', 'Presupuesto al 80 % y 100 %', description: 'Cuando te acercas al límite'),
        typeJson('weekly_summary', 'Resumen semanal (lunes 09:00)', push: weeklyPush),
      ],
    },
  ],
  'push_configured': true,
};

Map<String, FakeRoute> routes({bool failSave = false}) => {
  'GET /v1/notification-preferences': (_) => (200, preferencesBody()),
  'PUT /v1/notification-preferences': (_) =>
      failSave ? (500, {'message': 'error'}) : (200, preferencesBody(weeklyPush: true)),
};

Finder labelled(String label) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

CupertinoSwitch switchFor(WidgetTester tester, String label) =>
    tester.widget<CupertinoSwitch>(find.descendant(of: labelled(label), matching: find.byType(CupertinoSwitch)));

Future<void> pumpScreen(WidgetTester tester, FakeApi api, FakeReminderScheduler scheduler) => pumpFinance(
  tester,
  const NotificationSettingsScreen(),
  api,
  overrides: [
    reminderSchedulerProvider.overrideWithValue(scheduler),
    reminderClockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 10)),
    pendingCountReaderProvider.overrideWithValue(() async => 2),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the daily reminder and the server preferences grouped by module', (tester) async {
    await pumpScreen(tester, FakeApi(routes()), FakeReminderScheduler(permitted: true));

    expect(find.text('Avisos'), findsWidgets);
    expect(find.text('Recordatorio diario'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(switchFor(tester, 'Recordatorio diario').value, isTrue);
    expect(find.textContaining('Ajustes de iOS'), findsNothing);

    await tester.scrollUntilVisible(find.text('Resumen semanal (lunes 09:00)'), 200);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('FINANZAS'), findsOneWidget);
    expect(find.text('Cuando te acercas al límite'), findsOneWidget);
    expect(switchFor(tester, 'Push: Resumen semanal (lunes 09:00)').value, isFalse);
    expect(switchFor(tester, 'En la app: Resumen semanal (lunes 09:00)').value, isTrue);
    expect(find.textContaining('push-subscriptions'), findsNothing);
  });

  testWidgets('saves only the toggled preference', (tester) async {
    final api = FakeApi(routes());
    await pumpScreen(tester, api, FakeReminderScheduler(permitted: true));
    final label = 'Push: Resumen semanal (lunes 09:00)';
    await tester.scrollUntilVisible(labelled(label), 200);

    await tester.tap(find.descendant(of: labelled(label), matching: find.byType(CupertinoSwitch)));
    await settle(tester);

    final put = api.requests.singleWhere((request) => request.method == 'PUT');
    expect(put.data, {
      'preferences': [
        {'module': 'finance', 'type': 'weekly_summary', 'push': true, 'in_app': true},
      ],
    });
    expect(switchFor(tester, label).value, isTrue);
  });

  testWidgets('reverts the switch and warns when saving fails', (tester) async {
    await pumpScreen(tester, FakeApi(routes(failSave: true)), FakeReminderScheduler(permitted: true));
    final label = 'En la app: Pendientes por revisar (diario 20:00)';
    await tester.scrollUntilVisible(labelled(label), 200);

    await tester.tap(find.descendant(of: labelled(label), matching: find.byType(CupertinoSwitch)));
    await settle(tester);

    expect(switchFor(tester, label).value, isTrue);
    expect(find.text('No se han podido guardar las preferencias'), findsOneWidget);
    await tester.pump(defaultToastDuration);
  });

  testWidgets('turning the reminder off hides the time and cancels it', (tester) async {
    final scheduler = FakeReminderScheduler(permitted: true);
    await pumpScreen(tester, FakeApi(routes()), scheduler);

    await tester.tap(find.descendant(of: labelled('Recordatorio diario'), matching: find.byType(CupertinoSwitch)));
    await settle(tester);

    expect(find.text('20:00'), findsNothing);
    expect(scheduler.cancellations, 1);
    expect((await ReminderStore().read()).enabled, isFalse);
  });

  testWidgets('turning the reminder on asks for permission and shows a hint when denied', (tester) async {
    SharedPreferences.setMockInitialValues({'daily_reminder.enabled': false});
    final scheduler = FakeReminderScheduler(grantOnRequest: false);
    await pumpScreen(tester, FakeApi(routes()), scheduler);

    await tester.tap(find.descendant(of: labelled('Recordatorio diario'), matching: find.byType(CupertinoSwitch)));
    await settle(tester);

    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled, isEmpty);
    expect(find.textContaining('Actívalas en Ajustes de iOS'), findsOneWidget);
  });

  testWidgets('picks a new time from the sheet and reschedules', (tester) async {
    final scheduler = FakeReminderScheduler(permitted: true);
    await pumpScreen(tester, FakeApi(routes()), scheduler);

    await tester.tap(find.text('20:00'));
    await tester.pumpAndSettle();
    expect(find.text('Hora del recordatorio'), findsOneWidget);
    await tester.drag(find.text('20').last, const Offset(0, -64));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = (await ReminderStore().read()).time;
    expect(saved, isNot(ReminderTime.evening));
    expect(find.text(saved.label), findsOneWidget);
    expect(scheduler.lastScheduled?.$1, saved.nextAfter(DateTime(2026, 10, 26, 10)));
    expect(scheduler.lastScheduled?.$2.body, 'Tienes 2 elementos por revisar');
  });

  testWidgets('sends a test reminder', (tester) async {
    final scheduler = FakeReminderScheduler(permitted: true);
    await pumpScreen(tester, FakeApi(routes()), scheduler);

    await tester.tap(find.text('Probar aviso'));
    await settle(tester);

    expect(scheduler.shown.single.body, 'Tienes 2 elementos por revisar');
    expect(find.text('Aviso de prueba enviado'), findsOneWidget);
    await tester.pump(defaultToastDuration);
  });

  testWidgets('shows an error card when the preferences cannot be loaded', (tester) async {
    await pumpScreen(tester, FakeApi({}), FakeReminderScheduler(permitted: true));

    expect(find.text('No se han podido cargar los avisos'), findsOneWidget);
    expect(find.text('Recordatorio diario'), findsOneWidget);
  });
}
