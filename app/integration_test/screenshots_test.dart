import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/shell/app_shell.dart';

const prefix = String.fromEnvironment('SHOT_PREFIX', defaultValue: 'shot');
const theme = String.fromEnvironment('SHOT_THEME', defaultValue: 'light');

late IntegrationTestWidgetsFlutterBinding binding;

Future<void> idle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await idle(tester, 10);
  await binding.takeScreenshot('$prefix-$name-$theme');
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final vertical = find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down);

Future<void> tap(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 300, scrollable: vertical.last);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await idle(tester);
}

Future<void> tab(WidgetTester tester, String label) =>
    tap(tester, find.descendant(of: find.byType(CarliBottomNav), matching: find.text(label)));

Future<void> close(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await idle(tester);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the finance screens', (tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        unauthorizedHandlerProvider.overrideWith(
          (ref) => () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
    await idle(tester, 40);
    expect(container.read(authControllerProvider), isA<SignedIn>());

    await tab(tester, 'Movimientos');
    await tap(tester, find.text('Seleccionar'));
    await tap(tester, find.text('Mercadona'));
    await tap(tester, find.text('Carrefour'));
    await shot(tester, 'transactions-selection');
    await tap(tester, find.text('Terminar'));

    await tester.fling(find.byType(CustomScrollView).first, const Offset(0, 3000), 4000);
    await idle(tester);
    await tap(tester, find.text('Más filtros'));
    await shot(tester, 'more-filters');
    await close(tester);

    await tester.enterText(find.byType(TextField).first, 'Mercadona');
    await idle(tester, 30);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tap(tester, find.text('Compartido'));
    await idle(tester);
    await tester.drag(vertical.last, const Offset(0, -700));
    await idle(tester);
    await tester.drag(vertical.last, const Offset(0, -700));
    await shot(tester, 'sheet-extras');
    await close(tester);

    await tab(tester, 'Presupuestos');
    await tap(tester, find.text('Editar'));
    await shot(tester, 'budget-editor');
    await close(tester);
  });
}
