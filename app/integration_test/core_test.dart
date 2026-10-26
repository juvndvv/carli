import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/auth/current_user.dart';
import 'package:carli/core/pending/pending_providers.dart';
import 'package:carli/core/router/router.dart';
import 'package:carli/core/theme/theme_preference.dart';
import 'package:carli/shell/settings/settings_screen.dart';

const email = String.fromEnvironment('E2E_EMAIL', defaultValue: 'demo@example.com');
const password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'password');

Future<void> idle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('works through pending, notifications, appearance and security with real data', (tester) async {
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
    final router = container.read(routerProvider);

    final before = (await container.read(pendingSummaryProvider.future)).total;
    expect(before, greaterThan(0));
    router.go(Routes.pending);
    await idle(tester);
    expect(find.text('Pendientes'), findsWidgets);
    await tester.tap(find.text('Elegir categoría').first);
    await idle(tester, 10);
    if (find.bySemanticsLabel('Supermercado').evaluate().isEmpty) {
      await tester.tap(find.text('Ver todas').last);
      await idle(tester, 10);
    }
    await tester.tap(find.bySemanticsLabel('Supermercado').last);
    await idle(tester, 30);
    if (find.text('Ahora no').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ahora no').first);
      await idle(tester, 10);
    }
    expect(container.read(pendingTotalProvider), lessThan(before));

    router.go(Routes.notifications);
    await idle(tester);
    expect(find.text('Notificaciones'), findsWidgets);

    router.go(SettingsPaths.appearance);
    await idle(tester);
    await tester.tap(find.text('Oscuro').last);
    await idle(tester, 10);
    expect(container.read(themePreferenceProvider), ThemePreference.dark);
    await tester.tap(find.text('Sistema').last);
    await idle(tester, 10);
    expect(container.read(themePreferenceProvider), ThemePreference.system);

    router.go(SettingsPaths.security);
    await idle(tester, 30);
    await tester.scrollUntilVisible(find.text('Este dispositivo'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Este dispositivo'), findsOneWidget);

    router.go(Routes.home);
    await idle(tester);
  });
}
