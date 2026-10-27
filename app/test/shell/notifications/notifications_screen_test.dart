import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/core/notifications/notification.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/shell/notifications/notification_list.dart';
import 'package:carli/shell/notifications/notifications_home_card.dart';
import 'package:carli/shell/notifications/notifications_screen.dart';
import 'package:carli/shell/notifications/time_ago.dart';
import 'package:carli/shell/notifications/unread_dot.dart';
import 'package:carli/ui/toast.dart';

import '../../core/notifications/notification_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/test_app.dart';

final now = DateTime.parse('2026-10-24T10:00:00+02:00');

Future<GoRouter> pumpNotificationsRouter(WidgetTester tester, FakeApi api, {String initial = '/'}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(api, storage: {'auth_token': 'stored'});
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ListView(
            children: [
              const Align(alignment: Alignment.centerRight, child: NotificationsBellButton()),
              NotificationsHomeCard(now: now),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/notificaciones',
        builder: (context, state) => NotificationsScreen(now: now),
      ),
      GoRoute(
        path: '/mas/recurrentes',
        builder: (context, state) => const Scaffold(body: Text('Pantalla recurrentes')),
      ),
      GoRoute(
        path: '/finanzas/presupuestos',
        builder: (context, state) => Scaffold(body: Text('Presupuestos ${state.uri.queryParameters['periodo']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: carliTheme(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: Stack(children: [child!, const ToastHost()]),
        ),
      ),
    ),
  );
  await settle(tester);
  return router;
}

Iterable<String> markReadBodies(FakeApi api) =>
    api.requests.where((request) => request.path == '/v1/notifications/read').map((request) => '${request.data}');

Iterable<String> bodiesOf(FakeApi api, String path) =>
    api.requests.where((request) => request.path == path).map((request) => '${request.data}');

void main() {
  group('formatTimeAgo', () {
    DateTime ago(Duration duration) => now.subtract(duration);

    test('speaks Spanish relative time like Intl.RelativeTimeFormat', () {
      expect(formatTimeAgo(ago(const Duration(seconds: 20)), now: now), 'ahora');
      expect(formatTimeAgo(ago(const Duration(minutes: 1)), now: now), 'hace 1 minuto');
      expect(formatTimeAgo(ago(const Duration(minutes: 5)), now: now), 'hace 5 minutos');
      expect(formatTimeAgo(ago(const Duration(hours: 1)), now: now), 'hace 1 hora');
      expect(formatTimeAgo(ago(const Duration(hours: 3)), now: now), 'hace 3 horas');
      expect(formatTimeAgo(ago(const Duration(days: 1)), now: now), 'ayer');
      expect(formatTimeAgo(ago(const Duration(days: 2)), now: now), 'anteayer');
      expect(formatTimeAgo(ago(const Duration(days: 4)), now: now), 'hace 4 días');
      expect(formatTimeAgo(now.add(const Duration(days: 1)), now: now), 'mañana');
      expect(formatTimeAgo(now.add(const Duration(minutes: 10)), now: now), 'dentro de 10 minutos');
    });

    test('falls back to a short date after a week', () {
      expect(formatTimeAgo(DateTime(2026, 10, 10, 12), now: DateTime(2026, 10, 24, 12)), '10 oct');
      expect(formatTimeAgo(null, now: now), '');
    });
  });

  test('picks icons by notification type like Angular', () {
    AppNotification ofType(String type) => AppNotification.fromJson(notificationJson('n', type: type));
    expect(notificationIcon(ofType('budget_threshold')), 'triangle-alert');
    expect(notificationIcon(ofType('goal_reached')), 'target');
    expect(notificationIcon(ofType('upcoming_charge')), 'repeat');
    expect(notificationIcon(ofType('weekly_summary')), 'chart-column');
    expect(notificationIcon(ofType('debt_reminder')), 'hand-coins');
    expect(notificationIcon(ofType('payroll_overdue')), 'wallet');
    expect(notificationIcon(ofType('bank_sync_failed')), 'bell');
  });

  group('NotificationsScreen', () {
    testWidgets('lists notifications with relative times and unread dots', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [
            notificationJson('n1', createdAt: '2026-10-24T09:00:00+02:00'),
            notificationJson(
              'n2',
              type: 'goal_reached',
              title: 'Objetivo cumplido',
              body: null,
              readAt: '2026-10-23T09:00:00+02:00',
              createdAt: '2026-10-23T09:00:00+02:00',
            ),
          ],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      expect(find.text('Notificaciones'), findsWidgets);
      expect(find.text('Netflix 13,99 € pasado mañana'), findsOneWidget);
      expect(find.text('Cargo recurrente previsto. · hace 1 hora'), findsOneWidget);
      expect(find.text('Objetivo cumplido'), findsOneWidget);
      expect(find.text('ayer'), findsOneWidget);
      expect(find.byType(UnreadDot), findsOneWidget);
      expect(find.bySemanticsLabel('Marcar como leídas'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
    });

    testWidgets('shows the empty copy without the mark-all action', (tester) async {
      await pumpNotificationsRouter(tester, FakeApi(notificationRoutes()), initial: '/notificaciones');
      expect(find.text('No tienes notificaciones.'), findsOneWidget);
      expect(find.bySemanticsLabel('Marcar como leídas'), findsNothing);
    });

    testWidgets('shows an error with retry', (tester) async {
      var fail = true;
      final routes = notificationRoutes(items: [notificationJson('n1')]);
      final api = FakeApi({
        ...routes,
        'GET /v1/notifications': (options) =>
            fail ? (500, {'message': 'Server Error'}) : routes['GET /v1/notifications']!(options),
      });
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');
      expect(find.text('No se han podido cargar las notificaciones'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      expect(find.text('Netflix 13,99 € pasado mañana'), findsOneWidget);
    });

    testWidgets('marks everything read', (tester) async {
      final api = FakeApi(notificationRoutes(items: [notificationJson('n1'), notificationJson('n2')]));
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');
      expect(find.byType(UnreadDot), findsNWidgets(2));

      await tester.tap(find.bySemanticsLabel('Marcar como leídas'));
      await settle(tester);

      expect(markReadBodies(api), ['{all: true}']);
      expect(find.byType(UnreadDot), findsNothing);
      expect(find.bySemanticsLabel('Marcar como leídas'), findsNothing);
    });

    testWidgets('tapping a notification marks it read and opens its native route', (tester) async {
      final api = FakeApi(notificationRoutes(items: [notificationJson('n1')]));
      final router = await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      await tester.tap(find.text('Netflix 13,99 € pasado mañana'));
      await settle(tester);

      expect(markReadBodies(api), ['{ids: [n1]}']);
      expect(find.text('Pantalla recurrentes'), findsOneWidget);
      router.pop();
      await settle(tester);
      expect(find.byType(UnreadDot), findsNothing);
    });

    testWidgets('keeps query parameters on the mapped route', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [notificationJson('n1', type: 'budget_threshold', url: '/finanzas/presupuestos?periodo=p-1')],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');
      await tester.tap(find.text('Netflix 13,99 € pasado mañana'));
      await settle(tester);
      expect(find.text('Presupuestos p-1'), findsOneWidget);
    });

    testWidgets('read notifications without a native target stay on the inbox', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [notificationJson('n1', url: '/tareas', readAt: '2026-10-24T09:30:00+02:00')],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');
      await tester.tap(find.text('Netflix 13,99 € pasado mañana'));
      await settle(tester);
      expect(markReadBodies(api), isEmpty);
      expect(find.text('Netflix 13,99 € pasado mañana'), findsOneWidget);
    });

    testWidgets('loads more pages', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [notificationJson('n1')],
          lastPage: 2,
          pages: {
            2: [notificationJson('n2', title: 'Resumen semanal', type: 'weekly_summary')],
          },
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      await tester.tap(find.text('Cargar más'));
      await settle(tester);

      expect(find.text('Resumen semanal'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
    });

    testWidgets('groups unread and read notifications', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [
            notificationJson('n1', title: 'Nuevo aviso'),
            notificationJson('n2', title: 'Aviso visto', readAt: '2026-10-24T09:30:00+02:00'),
          ],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      expect(find.text('Sin leer'), findsOneWidget);
      expect(find.text('Leídas'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Nuevo aviso')).dy, lessThan(tester.getTopLeft(find.text('Leídas')).dy));
      expect(tester.getTopLeft(find.text('Aviso visto')).dy, greaterThan(tester.getTopLeft(find.text('Leídas')).dy));
    });

    testWidgets('swiping left deletes a notification', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [
            notificationJson('n1'),
            notificationJson('n2', title: 'Otro'),
          ],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      await tester.drag(find.text('Netflix 13,99 € pasado mañana'), const Offset(-600, 0));
      await settle(tester);
      await settle(tester);

      expect(bodiesOf(api, '/v1/notifications/delete'), ['{ids: [n1]}']);
      expect(find.text('Netflix 13,99 € pasado mañana'), findsNothing);
      expect(find.text('Otro'), findsOneWidget);
    });

    testWidgets('swiping right toggles read and unread', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [
            notificationJson('n1'),
            notificationJson('n2', title: 'Aviso visto', readAt: '2026-10-24T09:30:00+02:00'),
          ],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      await tester.drag(find.text('Netflix 13,99 € pasado mañana'), const Offset(600, 0));
      await settle(tester);
      expect(markReadBodies(api), ['{ids: [n1]}']);

      await tester.drag(find.text('Aviso visto'), const Offset(600, 0));
      await settle(tester);
      expect(bodiesOf(api, '/v1/notifications/unread'), ['{ids: [n2]}']);
      expect(find.byType(UnreadDot), findsOneWidget);
    });

    testWidgets('deletes every notification after confirming', (tester) async {
      var deleted = false;
      final routes = notificationRoutes(items: [notificationJson('n1')]);
      final api = FakeApi({
        ...routes,
        'GET /v1/notifications': (options) =>
            deleted ? (200, notificationsPageJson(const [])) : routes['GET /v1/notifications']!(options),
        'POST /v1/notifications/delete': (_) {
          deleted = true;
          return (200, {'deleted': 1, 'unread_count': 0});
        },
      });
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      await tester.tap(find.bySemanticsLabel('Borrar notificaciones'));
      await settle(tester);
      await tester.tap(find.text('Borrar todas'));
      await settle(tester);
      await tester.tap(find.text('Borrar todas').last);
      await settle(tester);

      expect(bodiesOf(api, '/v1/notifications/delete'), ['{all: true}']);
      expect(find.text('No tienes notificaciones.'), findsOneWidget);
      expect(find.bySemanticsLabel('Borrar notificaciones'), findsNothing);
    });

    testWidgets('deletes only read notifications', (tester) async {
      final api = FakeApi(
        notificationRoutes(
          items: [
            notificationJson('n1'),
            notificationJson('n2', title: 'Aviso visto', readAt: '2026-10-24T09:30:00+02:00'),
          ],
        ),
      );
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');

      await tester.tap(find.bySemanticsLabel('Borrar notificaciones'));
      await settle(tester);
      await tester.tap(find.text('Borrar leídas'));
      await settle(tester);

      expect(bodiesOf(api, '/v1/notifications/delete'), ['{read: true}']);
    });

    testWidgets('shows a toast when marking read fails', (tester) async {
      final api = FakeApi({
        ...notificationRoutes(items: [notificationJson('n1', url: null)]),
        'POST /v1/notifications/read': (_) => (500, {'message': 'Server Error'}),
      });
      await pumpNotificationsRouter(tester, api, initial: '/notificaciones');
      await tester.tap(find.text('Netflix 13,99 € pasado mañana'));
      await settle(tester);
      expect(find.text(markReadErrorMessage), findsOneWidget);
      expect(find.byType(UnreadDot), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Inicio', () {
    testWidgets('the home card shows the three most recent notifications and opens the inbox', (tester) async {
      final api = FakeApi(
        notificationRoutes(items: [for (var i = 1; i <= 5; i++) notificationJson('n$i', title: 'Aviso $i')]),
      );
      await pumpNotificationsRouter(tester, api);

      expect(find.text('Notificaciones recientes'), findsOneWidget);
      expect(find.text('Aviso 1'), findsOneWidget);
      expect(find.text('Aviso 3'), findsOneWidget);
      expect(find.text('Aviso 4'), findsNothing);

      await tester.tap(find.text('Ver todas'));
      await settle(tester);
      expect(find.text('Aviso 5'), findsOneWidget);
    });

    testWidgets('the home card shows the empty copy', (tester) async {
      await pumpNotificationsRouter(tester, FakeApi(notificationRoutes()));
      expect(find.text('No tienes notificaciones.'), findsOneWidget);
    });

    testWidgets('the bell shows the unread dot and opens the inbox', (tester) async {
      final api = FakeApi(notificationRoutes(items: [notificationJson('n1')], unreadCount: 2));
      await pumpNotificationsRouter(tester, api);

      final bell = find.bySemanticsLabel('Notificaciones (2 sin leer)');
      expect(bell, findsOneWidget);
      expect(
        find.descendant(of: find.byType(NotificationsBellButton), matching: find.byType(UnreadDot)),
        findsOneWidget,
      );

      await tester.tap(find.byType(NotificationsBellButton));
      await settle(tester);
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('the bell hides the dot when everything is read', (tester) async {
      await pumpNotificationsRouter(tester, FakeApi(notificationRoutes()));
      expect(find.bySemanticsLabel('Notificaciones'), findsOneWidget);
      expect(find.descendant(of: find.byType(NotificationsBellButton), matching: find.byType(UnreadDot)), findsNothing);
    });

    testWidgets('the dot uses the brand color', (tester) async {
      await pumpNotificationsRouter(tester, FakeApi(notificationRoutes(items: [notificationJson('n1')])));
      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(of: find.byType(UnreadDot), matching: find.byType(Container)).first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const Color(0xFFE5063F));
    });
  });
}
