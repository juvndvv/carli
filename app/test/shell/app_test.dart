import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/router/router.dart';
import 'package:carli/modules/finance/screens/transaction_sheet.dart';
import 'package:carli/modules/finance/ui/finance_home_card.dart';
import 'package:carli/shell/app_shell.dart';
import 'package:carli/shell/more/more_screen.dart';

import '../core/notifications/notification_fixtures.dart';
import '../core/pending/pending_fixtures.dart';
import '../support/fake_api.dart';
import '../support/finance_fixtures.dart';
import '../support/test_app.dart';
import 'settings/settings_fixtures.dart';

Future<FakeApi> pumpApp(WidgetTester tester, FakeApi api, {Map<String, String> storage = const {}}) async {
  final container = testContainer(api, storage: storage);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
  await tester.pumpAndSettle();
  return api;
}

Finder navLabel(String label) => find.descendant(of: find.byType(CarliBottomNav), matching: find.text(label));

Future<void> openFinance(WidgetTester tester) async {
  await tester.tap(navLabel('Finanzas'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the login screen without a session', (tester) async {
    await pumpApp(tester, FakeApi({}));

    expect(find.text('Tu asistente personal'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('asks for credentials before calling the api', (tester) async {
    final api = await pumpApp(tester, FakeApi({}));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Introduce tu email y tu contraseña.'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('shows the validation message for wrong credentials', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'POST /v1/auth/token': (_) => (
          422,
          {
            'message': 'Estas credenciales no coinciden con nuestros registros.',
            'errors': {
              'email': ['Estas credenciales no coinciden con nuestros registros.'],
            },
          },
        ),
      }),
    );

    await tester.enterText(find.byType(TextField).at(0), 'juanda@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Estas credenciales no coinciden con nuestros registros.'), findsOneWidget);
  });

  testWidgets('completes the two factor challenge and opens the shell', (tester) async {
    final api = await pumpApp(
      tester,
      FakeApi({
        'POST /v1/auth/token': (options) => (options.data as Map).containsKey('code')
            ? (201, {'token': '1|plain', 'user': testUser})
            : (200, {'two_factor': true}),
      }),
    );

    await tester.enterText(find.byType(TextField).at(0), 'juanda@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Verificación en dos pasos'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar'));
    await tester.pumpAndSettle();

    expect(api.requests.lastWhere((request) => request.path == '/v1/auth/token').data, containsPair('code', '123456'));
    expect(find.byType(CarliBottomNav), findsOneWidget);
  });

  testWidgets('returns to the interrupted screen after the session expires and the user signs in again', (tester) async {
    final container = testContainer(
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'POST /v1/auth/token': (_) => (201, {'token': '2|plain', 'user': testUser}),
      }),
      storage: {'auth_token': 'stored'},
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.budgets);
    await tester.pumpAndSettle();

    await container.read(authControllerProvider.notifier).handleUnauthorized();
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'juanda@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).routeInformationProvider.value.uri.path, Routes.budgets);
  });

  testWidgets('switches tabs from the bottom navigation', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
      }),
      storage: {'auth_token': 'stored'},
    );

    await openFinance(tester);
    for (final label in ['Inicio', 'Resumen', 'Movimientos', 'Presupuestos', 'Más']) {
      expect(navLabel(label), findsOneWidget);
    }

    await tester.tap(navLabel('Presupuestos'));
    await tester.pumpAndSettle();

    expect(find.text('Presupuestos'), findsNWidgets(2));
  });

  testWidgets('lists the modules beside a pinned Inicio on the home screen', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'GET /v1/modules': (_) => (200, {'data': modulesJson()}),
      }),
      storage: {'auth_token': 'stored'},
    );

    expect(navLabel('Inicio'), findsOneWidget);
    expect(navLabel('Finanzas'), findsOneWidget);
    expect(find.bySemanticsLabel('Tareas, próximamente'), findsOneWidget);
    expect(navLabel('Resumen'), findsNothing);
    expect(find.bySemanticsLabel('Nuevo movimiento'), findsNothing);

    await openFinance(tester);

    expect(navLabel('Resumen'), findsOneWidget);
    expect(navLabel('Finanzas'), findsNothing);
    expect(find.bySemanticsLabel('Nuevo movimiento'), findsOneWidget);

    await tester.tap(navLabel('Inicio'));
    await tester.pumpAndSettle();

    expect(navLabel('Finanzas'), findsOneWidget);
    expect(navLabel('Resumen'), findsNothing);
  });

  testWidgets('scrolls the tabs beside Inicio on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'GET /v1/modules': (_) => (200, {'data': modulesJson()}),
      }),
      storage: {'auth_token': 'stored'},
    );

    await openFinance(tester);
    await tester.tap(navLabel('Más'));
    await tester.pumpAndSettle();

    final nav = tester.getRect(find.byType(CarliBottomNav));
    expect(nav.contains(tester.getCenter(navLabel('Más'))), isTrue);
    expect(tester.getCenter(navLabel('Inicio')).dx, lessThan(tester.getCenter(navLabel('Más')).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens Ajustes from the avatar on Inicio', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
      }),
      storage: {'auth_token': 'stored'},
    );

    await tester.tap(find.bySemanticsLabel('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsWidgets);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('leaves the modules the user turned off out of the home tabs', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'GET /v1/modules': (_) => (200, {'data': modulesJson(financeEnabled: false)}),
      }),
      storage: {'auth_token': 'stored'},
    );

    expect(navLabel('Finanzas'), findsNothing);
    expect(navLabel('Tareas'), findsOneWidget);
  });

  testWidgets('opens a coming soon module from the home tabs', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'GET /v1/modules': (_) => (200, {'data': modulesJson()}),
      }),
      storage: {'auth_token': 'stored'},
    );

    await tester.tap(navLabel('Tareas'));
    await tester.pumpAndSettle();

    expect(find.text('Próximamente'), findsOneWidget);
    expect(find.text('Listas, recordatorios y proyectos personales.'), findsOneWidget);
    expect(navLabel('Finanzas'), findsOneWidget);
  });

  testWidgets('puts the recent notifications first on the home screen only when there are some', (tester) async {
    Future<double> notificationsOffset(List<Map<String, Object?>> items) async {
      await pumpApp(
        tester,
        FakeApi({
          'GET /v1/me': (_) => (200, {'data': testUser}),
          ...notificationRoutes(items: items),
        }),
        storage: {'auth_token': 'stored'},
      );
      return tester.getTopLeft(find.text('Notificaciones recientes')).dy -
          tester.getTopLeft(find.byType(FinanceHomeCard)).dy;
    }

    expect(await notificationsOffset([notificationJson('1')]), isNegative);
    expect(await notificationsOffset(const []), isPositive);
  });

  testWidgets('shows pending and unread counts in the tab bar, Inicio and Más', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'GET /v1/pending/summary': (_) => (200, pendingSummaryJson()),
        'GET /v1/notifications/unread-count': (_) => (200, {'unread_count': 2}),
      }),
      storage: {'auth_token': 'stored'},
    );

    expect(find.text('3 elementos por revisar'), findsOneWidget);
    expect(find.bySemanticsLabel('Notificaciones (2 sin leer)'), findsOneWidget);

    await openFinance(tester);
    expect(find.bySemanticsLabel('Más, 3 pendientes'), findsOneWidget);

    await tester.tap(navLabel('Más'));
    await tester.pumpAndSettle();

    expect(find.text('3 elementos por revisar'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
  });

  testWidgets('logs out from the more tab', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        'DELETE /v1/auth/token': (_) => (204, null),
      }),
      storage: {'auth_token': 'stored'},
    );

    await openFinance(tester);
    await tester.tap(navLabel('Más'));
    await tester.pumpAndSettle();
    final page = find.descendant(of: find.byType(MoreScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200, scrollable: page);
    await tester.drag(page, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('opens the new movement sheet from the + button beside the tab bar', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        ...financeBaseRoutes(),
      }),
      storage: {'auth_token': 'stored'},
    );

    await openFinance(tester);
    await tester.tap(find.bySemanticsLabel('Nuevo movimiento'));
    await tester.pumpAndSettle();

    final sheet = tester.element(find.byType(TransactionSheet));
    expect(Navigator.of(sheet), same(Navigator.of(sheet, rootNavigator: true)));
    expect(find.text('Nuevo movimiento'), findsOneWidget);
  });
}
