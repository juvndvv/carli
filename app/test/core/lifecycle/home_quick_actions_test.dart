import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/app.dart';
import 'package:carli/core/lifecycle/home_quick_actions.dart';
import 'package:carli/core/router/router.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

class FakeQuickActions implements QuickActionsPlatform {
  void Function(String type)? _onAction;
  List<HomeQuickAction> published = const [];

  void trigger(String type) => _onAction!(type);

  @override
  Future<void> initialize(void Function(String type) onAction) async => _onAction = onAction;

  @override
  Future<void> publish(List<HomeQuickAction> actions) async => published = actions;
}

Future<(ProviderContainer, FakeQuickActions)> pumpWithQuickActions(
  WidgetTester tester, {
  Map<String, String> storage = const {},
}) async {
  final quickActions = FakeQuickActions();
  final container = testContainer(
    FakeApi({
      'GET /v1/me': (_) => (200, {'data': testUser}),
      'POST /v1/auth/token': (_) => (201, {'token': '1|plain', 'user': testUser}),
    }),
    storage: storage,
    overrides: [quickActionsPlatformProvider.overrideWithValue(quickActions)],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
  await tester.pumpAndSettle();
  return (container, quickActions);
}

String locationOf(ProviderContainer container) =>
    container.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('publishes the home screen shortcuts and opens the chosen one', (tester) async {
    final (container, quickActions) = await pumpWithQuickActions(tester, storage: {'auth_token': 'stored'});

    expect(quickActions.published.map((action) => action.title), ['Nuevo movimiento', 'Movimientos', 'Pendientes']);

    quickActions.trigger('transactions');
    await tester.pump(const Duration(milliseconds: 500));

    expect(locationOf(container), Routes.transactions);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('waits for the sign in before opening a shortcut', (tester) async {
    final (container, quickActions) = await pumpWithQuickActions(tester);

    quickActions.trigger('pending');
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'juanda@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Entrar'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(locationOf(container), Routes.pending);
  });
}
