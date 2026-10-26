import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/modules/finance/screens/transaction_sheet.dart';
import 'package:carli/shell/app_shell.dart';

const email = String.fromEnvironment('E2E_EMAIL', defaultValue: 'demo@example.com');
const password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'password');

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 15),
);

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(CarliBottomNav), matching: find.text(label)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logs in and walks through finance with real data', (tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        unauthorizedHandlerProvider.overrideWith(
          (ref) =>
              () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
    await settle(tester);

    if (container.read(authControllerProvider) is! SignedIn) {
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.tap(find.text('Entrar'));
      await settle(tester);
    }
    expect(container.read(authControllerProvider), isA<SignedIn>());

    await waitFor(tester, find.text('Patrimonio neto'));

    await openTab(tester, 'Resumen');
    await waitFor(tester, find.text('Ingresos y gastos'));

    await openTab(tester, 'Presupuestos');
    await waitFor(tester, find.text('Por categoría'));

    await openTab(tester, 'Movimientos');
    await waitFor(tester, find.textContaining('movimientos'));

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.enterText(
      find.descendant(of: find.byType(TransactionSheet), matching: find.byType(TextField)).first,
      '12,34',
    );
    await tester.tap(find.text('Alimentación'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await waitFor(tester, find.text('Movimiento guardado'));
    await tester.tap(find.text('Deshacer'));
    await tester.pump(const Duration(seconds: 2));
  });
}
