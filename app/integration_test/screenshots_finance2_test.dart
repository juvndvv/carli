import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/router/router.dart';
import 'package:carli/modules/finance/data/finance_providers.dart';

const prefix = String.fromEnvironment('SHOT_PREFIX', defaultValue: 'finance2');
const theme = String.fromEnvironment('SHOT_THEME', defaultValue: 'light');

late IntegrationTestWidgetsFlutterBinding binding;

Future<void> idle(WidgetTester tester, [int ticks = 25]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the finance sections behind Más', (tester) async {
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
    if (container.read(authControllerProvider) is! SignedIn) {
      await tester.enterText(find.byType(TextField).at(0), 'demo@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('Entrar'));
      await idle(tester, 40);
    }
    expect(container.read(authControllerProvider), isA<SignedIn>());
    final router = container.read(routerProvider);

    Future<void> visit(String location, String name) async {
      router.go(location);
      await idle(tester);
      await binding.takeScreenshot('$prefix-$name-$theme');
    }

    await visit(Routes.more, 'more');
    await visit(Routes.accounts, 'accounts');
    final accounts = await container.read(accountsProvider.future);
    await visit(Routes.account(accounts.active.first.id), 'account-detail');
    await visit(Routes.categories, 'categories');
    await visit(Routes.recurring, 'recurring');
    await visit(Routes.goals, 'goals');
    await visit(Routes.debts, 'debts');
    await visit(Routes.shared, 'shared');
    await visit(Routes.financeSettings, 'settings');
    await visit(Routes.banks, 'banks');
    router.go(Routes.home);
    await idle(tester);
  });
}
