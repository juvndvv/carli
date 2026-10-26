import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/app.dart';
import 'package:carli/modules/finance/screens/transaction_sheet.dart';
import 'package:carli/shell/app_shell.dart';

import '../core/pending/pending_fixtures.dart';
import '../support/fake_api.dart';
import '../support/finance_fixtures.dart';
import '../support/test_app.dart';

Future<FakeApi> pumpApp(WidgetTester tester, FakeApi api, {Map<String, String> storage = const {}}) async {
  final container = testContainer(api, storage: storage);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
  await tester.pumpAndSettle();
  return api;
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

  testWidgets('switches tabs from the bottom navigation', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
      }),
      storage: {'auth_token': 'stored'},
    );

    for (final label in ['Inicio', 'Resumen', 'Movimientos', 'Presupuestos', 'Más']) {
      expect(find.descendant(of: find.byType(CarliBottomNav), matching: find.text(label)), findsOneWidget);
    }

    await tester.tap(find.descendant(of: find.byType(CarliBottomNav), matching: find.text('Presupuestos')));
    await tester.pumpAndSettle();

    expect(find.text('Presupuestos'), findsNWidgets(2));
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

    expect(find.bySemanticsLabel('Más, 3 pendientes'), findsOneWidget);
    expect(find.text('3 elementos por revisar'), findsOneWidget);
    expect(find.bySemanticsLabel('Notificaciones (2 sin leer)'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(CarliBottomNav), matching: find.text('Más')));
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

    await tester.tap(find.descendant(of: find.byType(CarliBottomNav), matching: find.text('Más')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('opens the new movement sheet from the FAB above the tab bar', (tester) async {
    await pumpApp(
      tester,
      FakeApi({
        'GET /v1/me': (_) => (200, {'data': testUser}),
        ...financeBaseRoutes(),
      }),
      storage: {'auth_token': 'stored'},
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final sheet = tester.element(find.byType(TransactionSheet));
    expect(Navigator.of(sheet), same(Navigator.of(sheet, rootNavigator: true)));
    expect(find.text('Nuevo movimiento'), findsOneWidget);
  });
}
