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
const email = String.fromEnvironment('E2E_EMAIL', defaultValue: 'demo@example.com');
const password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'password');

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

Future<void> tap(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await idle(tester);
}

Future<void> tab(WidgetTester tester, String label) =>
    tap(tester, find.descendant(of: find.byType(CarliBottomNav), matching: find.text(label)));

Future<void> back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await idle(tester);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the tasks screens', (tester) async {
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
    await idle(tester, 40);
    if (container.read(authControllerProvider) is! SignedIn) {
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.tap(find.text('Entrar'));
      await idle(tester, 40);
    }
    expect(container.read(authControllerProvider), isA<SignedIn>());

    await shot(tester, 'tasks-home');
    await tab(tester, 'Tareas');
    await shot(tester, 'tasks-today');
    await tab(tester, 'Próximas');
    await shot(tester, 'tasks-upcoming');
    await tab(tester, 'Listas');
    await shot(tester, 'tasks-lists');
    await tab(tester, 'Plantillas');
    await shot(tester, 'tasks-templates');
    await tap(tester, find.text('Sacar la basura'));
    await shot(tester, 'tasks-template-editor');
    await back(tester);
    await tab(tester, 'Hoy');
    await tap(tester, find.bySemanticsLabel('Nueva tarea'));
    await shot(tester, 'tasks-new');
    await back(tester);
    await tap(tester, find.text('Comprar regalo para Ana'));
    await shot(tester, 'tasks-detail');
  });
}
