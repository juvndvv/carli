import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/push/push_platform.dart';
import 'package:carli/shell/settings/notifications/notification_settings_screen.dart';
import 'package:carli/ui/toast.dart';

import '../../../support/fake_api.dart';
import '../../../support/fake_push_platform.dart';
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

Map<String, FakeRoute> routes({bool failSave = false, bool serverPush = true}) => {
  'GET /v1/notification-preferences': (_) => (200, preferencesBody()),
  'POST /v1/push-devices': (_) => (
    201,
    {
      'data': {'id': 'device', 'environment': 'sandbox'},
      'push_configured': serverPush,
    },
  ),
  'POST /v1/notifications/test': (_) => (
    202,
    {
      'channels': ['database', if (serverPush) r'App\Core\Push\ApnsChannel'],
    },
  ),
  'PUT /v1/notification-preferences': (_) =>
      failSave ? (500, {'message': 'error'}) : (200, preferencesBody(weeklyPush: true)),
};

Finder labelled(String label) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

CupertinoSwitch switchFor(WidgetTester tester, String label) =>
    tester.widget<CupertinoSwitch>(find.descendant(of: labelled(label), matching: find.byType(CupertinoSwitch)));

Future<void> pumpScreen(WidgetTester tester, FakeApi api, FakePushPlatform platform) => pumpFinance(
  tester,
  const NotificationSettingsScreen(),
  api,
  overrides: [pushPlatformProvider.overrideWithValue(platform)],
);

FakePushPlatform granted() => FakePushPlatform(currentPermission: PushPermission.granted);

Future<void> activatePush(WidgetTester tester) async {
  await tester.tap(find.text('Activar notificaciones'));
  await settle(tester);
}

void main() {
  testWidgets('shows the push status and the server preferences grouped by module', (tester) async {
    await pumpScreen(tester, FakeApi(routes()), granted());

    expect(find.text('Avisos'), findsWidgets);
    expect(find.text('Notificaciones push'), findsOneWidget);
    expect(find.textContaining('Ajustes de iOS'), findsNothing);

    await tester.scrollUntilVisible(find.text('Resumen semanal (lunes 09:00)'), 200);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('Cuando te acercas al límite'), findsOneWidget);
    expect(switchFor(tester, 'Push: Resumen semanal (lunes 09:00)').value, isFalse);
    expect(switchFor(tester, 'En la app: Resumen semanal (lunes 09:00)').value, isTrue);
    expect(find.textContaining('push-subscriptions'), findsNothing);
  });

  testWidgets('saves only the toggled preference', (tester) async {
    final api = FakeApi(routes());
    await pumpScreen(tester, api, granted());
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
    await pumpScreen(tester, FakeApi(routes(failSave: true)), granted());
    final label = 'En la app: Pendientes por revisar (diario 20:00)';
    await tester.scrollUntilVisible(labelled(label), 200);

    await tester.tap(find.descendant(of: labelled(label), matching: find.byType(CupertinoSwitch)));
    await settle(tester);

    expect(switchFor(tester, label).value, isTrue);
    expect(find.text('No se han podido guardar los ajustes de avisos'), findsOneWidget);
    await tester.pump(defaultToastDuration);
  });

  testWidgets('asks for permission and registers this iPhone with the server', (tester) async {
    final api = FakeApi(routes());
    final platform = FakePushPlatform();
    await pumpScreen(tester, api, platform);

    expect(find.text('Aún no las has permitido'), findsOneWidget);
    await activatePush(tester);

    expect(platform.permissionRequests, 1);
    final post = api.requests.singleWhere((request) => request.path == '/v1/push-devices');
    expect(post.data, {'token': FakePushPlatform.token, 'environment': 'sandbox'});
    expect(find.text('Activadas en este iPhone'), findsOneWidget);
  });

  testWidgets('shows a hint when iOS notifications are denied', (tester) async {
    final platform = FakePushPlatform(grantOnRequest: false);
    await pumpScreen(tester, FakeApi(routes()), platform);

    await activatePush(tester);

    expect(platform.registrations, 0);
    expect(find.text('Desactivadas en iOS'), findsOneWidget);
    expect(find.textContaining('Actívalas en Ajustes de iOS'), findsOneWidget);
  });

  testWidgets('offers a retry when APNs registration fails', (tester) async {
    await pumpScreen(tester, FakeApi(routes()), FakePushPlatform(failRegistration: true));

    await activatePush(tester);

    expect(find.text('No se ha podido registrar este iPhone'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('sends a test push through the server', (tester) async {
    final api = FakeApi(routes());
    await pumpScreen(tester, api, FakePushPlatform());
    await activatePush(tester);

    await tester.tap(find.text('Probar aviso'));
    await settle(tester);

    expect(api.requests.where((request) => request.path == '/v1/notifications/test'), hasLength(1));
    expect(find.text('Aviso de prueba enviado'), findsOneWidget);
    await tester.pump(defaultToastDuration);
  });

  testWidgets('explains when the server cannot send push yet', (tester) async {
    await pumpScreen(tester, FakeApi(routes(serverPush: false)), FakePushPlatform());
    await activatePush(tester);

    expect(find.text('El servidor aún no tiene el envío push configurado'), findsOneWidget);
    await tester.tap(find.text('Probar aviso'));
    await settle(tester);

    expect(find.text('El aviso de prueba solo ha llegado a la bandeja'), findsOneWidget);
    await tester.pump(defaultToastDuration);
  });

  testWidgets('shows an error card when the preferences cannot be loaded', (tester) async {
    await pumpScreen(tester, FakeApi({}), granted());

    expect(find.text('No se han podido cargar los avisos'), findsOneWidget);
    expect(find.text('Notificaciones push'), findsOneWidget);
  });
}
