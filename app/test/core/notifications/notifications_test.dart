import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/notifications/notification.dart';
import 'package:carli/core/notifications/notification_route.dart';
import 'package:carli/core/notifications/notifications_providers.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';
import 'notification_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('models', () {
    test('map the paginated inbox like the Angular store', () {
      final page = NotificationsPage.fromJson(
        notificationsPageJson([notificationJson('n1')], currentPage: 1, lastPage: 2, unreadCount: 7),
      );
      final item = page.items.single;
      expect(item.id, 'n1');
      expect(item.module, 'finance');
      expect(item.type, 'upcoming_charge');
      expect(item.title, 'Netflix 13,99 € pasado mañana');
      expect(item.body, 'Cargo recurrente previsto.');
      expect(item.url, '/finanzas/recurrentes');
      expect(item.unread, isTrue);
      expect(item.createdAt, DateTime.utc(2026, 10, 24, 7));
      expect(page.unreadCount, 7);
      expect(page.nextPage, 2);
    });

    test('fall back to empty strings for missing type and title', () {
      final item = AppNotification.fromJson(
        notificationJson('n1', type: null, title: null, readAt: '2026-10-24T10:00:00+02:00'),
      );
      expect(item.type, '');
      expect(item.title, '');
      expect(item.unread, isFalse);
    });

    test('stop paging on the last page', () {
      expect(NotificationsPage.fromJson(notificationsPageJson([], currentPage: 2, lastPage: 2)).nextPage, isNull);
    });
  });

  group('notificationsProvider', () {
    test('loads the first page, adopts the unread count and pages through', () async {
      final api = FakeApi(
        notificationRoutes(
          items: [notificationJson('n1'), notificationJson('n2')],
          lastPage: 2,
          unreadCount: 7,
          pages: {
            2: [notificationJson('n2'), notificationJson('n3')],
          },
        ),
      );
      final container = testContainer(api);
      final state = await container.read(notificationsProvider.future);

      expect(state.items.map((item) => item.id), ['n1', 'n2']);
      expect(state.hasMore, isTrue);
      expect(container.read(unreadNotificationsCountProvider).value, 7);
      expect(api.requests.first.queryParameters, {'page': 1});

      await container.read(notificationsProvider.notifier).loadMore();
      final more = container.read(notificationsProvider).value!;
      expect(more.items.map((item) => item.id), ['n1', 'n2', 'n3']);
      expect(more.hasMore, isFalse);
      expect(api.requests.last.queryParameters, {'page': 2});
    });

    test('exposes the three most recent notifications for Inicio', () async {
      final api = FakeApi(notificationRoutes(items: [for (var i = 1; i <= 5; i++) notificationJson('n$i')]));
      final container = testContainer(api);
      final state = await container.read(notificationsProvider.future);
      expect(state.recent.map((item) => item.id), ['n1', 'n2', 'n3']);
    });

    test('marks one notification read optimistically and adopts the server count', () async {
      final api = FakeApi(
        notificationRoutes(
          items: [notificationJson('n1'), notificationJson('n2')],
          unreadCount: 5,
          markedUnreadCount: 3,
        ),
      );
      final container = testContainer(api);
      await container.read(notificationsProvider.future);

      final pending = container.read(notificationsProvider.notifier).markRead(['n1']);
      final optimistic = container.read(notificationsProvider).value!.items;
      expect(optimistic.first.unread, isFalse);
      expect(optimistic.last.unread, isTrue);
      expect(container.read(unreadNotificationsCountProvider).value, 4);

      await pending;
      final request = api.requests.last;
      expect(request.path, '/v1/notifications/read');
      expect(request.data, {
        'ids': ['n1'],
      });
      expect(container.read(unreadNotificationsCountProvider).value, 3);
    });

    test('marks everything read with the all flag', () async {
      final api = FakeApi(notificationRoutes(items: [notificationJson('n1'), notificationJson('n2')], unreadCount: 9));
      final container = testContainer(api);
      await container.read(notificationsProvider.future);

      final pending = container.read(notificationsProvider.notifier).markAllRead();
      expect(container.read(notificationsProvider).value!.items.every((item) => !item.unread), isTrue);
      expect(container.read(unreadNotificationsCountProvider).value, 0);
      await pending;
      expect(api.requests.last.data, {'all': true});
    });

    test('rolls the optimistic update back when the server fails', () async {
      final api = FakeApi({
        ...notificationRoutes(items: [notificationJson('n1')], unreadCount: 1),
        'POST /v1/notifications/read': (_) => (500, {'message': 'Server Error'}),
      });
      final container = testContainer(api);
      await container.read(notificationsProvider.future);

      await expectLater(container.read(notificationsProvider.notifier).markRead(['n1']), throwsA(anything));
      expect(container.read(notificationsProvider).value!.items.single.unread, isTrue);
      expect(container.read(unreadNotificationsCountProvider).value, 1);
    });

    test('keeps the loaded list when a refresh fails', () async {
      var fail = false;
      final routes = notificationRoutes(items: [notificationJson('n1')]);
      final api = FakeApi({
        ...routes,
        'GET /v1/notifications': (options) =>
            fail ? (500, {'message': 'Server Error'}) : routes['GET /v1/notifications']!(options),
      });
      final container = testContainer(api);
      await container.read(notificationsProvider.future);

      fail = true;
      await container.read(notificationsProvider.notifier).refresh();
      expect(container.read(notificationsProvider).value!.items.single.id, 'n1');
    });
  });

  group('unreadNotificationsCountProvider', () {
    test('reads the unread count endpoint on its own', () async {
      final api = FakeApi(notificationRoutes(unreadCount: 4));
      final container = testContainer(api);
      expect(await container.read(unreadNotificationsCountProvider.future), 4);
      expect(api.requests.single.path, '/v1/notifications/unread-count');
    });

    test('refreshes through the count endpoint while the inbox is not loaded', () async {
      var unread = 1;
      final api = FakeApi({
        'GET /v1/notifications/unread-count': (_) => (200, {'unread_count': unread}),
      });
      final container = testContainer(api);
      await container.read(unreadNotificationsCountProvider.future);

      unread = 6;
      await container.read(unreadNotificationsCountProvider.notifier).refresh();
      expect(container.read(unreadNotificationsCountProvider).value, 6);
      expect(api.requests.where((request) => request.path == '/v1/notifications'), isEmpty);
    });

    test('refreshes the inbox when it is loaded', () async {
      final api = FakeApi(notificationRoutes(items: [notificationJson('n1')], unreadCount: 2));
      final container = testContainer(api);
      final subscription = container.listen(notificationsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(notificationsProvider.future);
      final before = api.requests.where((request) => request.path == '/v1/notifications').length;

      await container.read(unreadNotificationsCountProvider.notifier).refresh();
      expect(api.requests.where((request) => request.path == '/v1/notifications').length, before + 1);
      expect(container.read(unreadNotificationsCountProvider).value, 2);
    });
  });

  group('nativeNotificationRoute', () {
    test('maps every backend notification target to a native route', () {
      expect(nativeNotificationRoute('/finanzas'), '/finanzas');
      expect(nativeNotificationRoute('/finanzas/recurrentes'), '/mas/recurrentes');
      expect(nativeNotificationRoute('/finanzas/deudas'), '/mas/deudas');
      expect(nativeNotificationRoute('/finanzas/ajustes/bancos'), '/mas/ajustes-finanzas/bancos');
      expect(nativeNotificationRoute('/finanzas/objetivos/goal-1'), '/mas/objetivos/goal-1');
      expect(nativeNotificationRoute('/finanzas/presupuestos?periodo=p-1'), '/finanzas/presupuestos?periodo=p-1');
      expect(
        nativeNotificationRoute('/finanzas/movimientos/nuevo?tipo=ingreso'),
        '/finanzas/movimientos/nuevo?tipo=ingreso',
      );
      expect(nativeNotificationRoute('/pendientes'), '/pendientes');
      expect(nativeNotificationRoute('/habitos/hoy'), '/habitos/hoy');
      expect(nativeNotificationRoute('/ajustes'), '/mas/ajustes');
    });

    test('maps the remaining Angular finance routes', () {
      expect(nativeNotificationRoute('/'), '/');
      expect(nativeNotificationRoute('/finanzas/movimientos?sin_categoria=1'), '/finanzas/movimientos?sin_categoria=1');
      expect(nativeNotificationRoute('/finanzas/cuentas'), '/mas/cuentas');
      expect(nativeNotificationRoute('/finanzas/cuentas/acc-1'), '/mas/cuentas/acc-1');
      expect(nativeNotificationRoute('/finanzas/categorias'), '/mas/categorias');
      expect(nativeNotificationRoute('/finanzas/objetivos'), '/mas/objetivos');
      expect(nativeNotificationRoute('/finanzas/compartidos'), '/mas/compartidos');
      expect(nativeNotificationRoute('/finanzas/compartidos/c-1'), '/mas/compartidos/c-1');
      expect(nativeNotificationRoute('/finanzas/ajustes'), '/mas/ajustes-finanzas');
      expect(
        nativeNotificationRoute('/finanzas/ajustes/bancos/conn-1/vincular?renovado=1'),
        '/mas/ajustes-finanzas/bancos/conn-1/vincular?renovado=1',
      );
      expect(nativeNotificationRoute('/ajustes/notificaciones'), '/mas/ajustes/avisos');
      expect(nativeNotificationRoute('/notificaciones'), '/notificaciones');
      expect(nativeNotificationRoute('/finanzas/recurrentes/'), '/mas/recurrentes');
    });

    test('passes native routes through', () {
      expect(nativeNotificationRoute('/mas'), '/mas');
      expect(nativeNotificationRoute('/mas/cuentas/acc-1'), '/mas/cuentas/acc-1');
      expect(nativeNotificationRoute('/mas/ajustes-finanzas/bancos'), '/mas/ajustes-finanzas/bancos');
    });

    test('returns null for missing, external or unknown targets', () {
      expect(nativeNotificationRoute(null), isNull);
      expect(nativeNotificationRoute(''), isNull);
      expect(nativeNotificationRoute('https://bank.example/authorize'), isNull);
      expect(nativeNotificationRoute('/tareas'), isNull);
      expect(nativeNotificationRoute('/finanzas/desconocido'), isNull);
      expect(nativeNotificationRoute('/mas/categorias/x'), isNull);
    });
  });
}
