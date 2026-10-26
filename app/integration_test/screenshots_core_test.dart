import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/api/api_client.dart';
import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/core/pending/pending_providers.dart';
import 'package:carli/core/reminders/pending_count_reader.dart';
import 'package:carli/core/router/router.dart';
import 'package:carli/shell/settings/settings_screen.dart';

const prefix = String.fromEnvironment('SHOT_PREFIX', defaultValue: 'core');
const theme = String.fromEnvironment('SHOT_THEME', defaultValue: 'light');

late IntegrationTestWidgetsFlutterBinding binding;

Future<void> idle(WidgetTester tester, [int ticks = 25]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the core screens', (tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        unauthorizedHandlerProvider.overrideWith(
          (ref) =>
              () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
        ),
        pendingCountReaderProvider.overrideWith(
          (ref) =>
              () => currentPendingCount(ref.read),
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

    await visit(Routes.home, 'home');
    await visit(Routes.pending, 'pending');
    await visit(Routes.notifications, 'notifications');
    router.go(Routes.search);
    await idle(tester, 10);
    await tester.enterText(find.byType(TextField).first, 'cuenta');
    await idle(tester);
    await binding.takeScreenshot('$prefix-search-$theme');
    await visit(Routes.more, 'more');
    await visit(SettingsPaths.root, 'settings');
    await visit(SettingsPaths.profile, 'profile');
    await visit(SettingsPaths.security, 'security');
    await visit(SettingsPaths.notifications, 'notification-settings');
    await visit(SettingsPaths.modules, 'modules');
    await visit(SettingsPaths.appearance, 'appearance');
    router.go(Routes.home);
    await idle(tester);
  });
}
