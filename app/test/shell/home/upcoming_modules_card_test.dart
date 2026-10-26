import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/theme/theme.dart';
import 'package:carli/shell/home/upcoming_modules_card.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';
import '../settings/settings_fixtures.dart';

Future<void> pumpCard(WidgetTester tester, FakeApi api) async {
  final container = testContainer(api);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: carliTheme(Brightness.light),
        home: const Scaffold(body: UpcomingModulesCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the modules that are coming soon', (tester) async {
    await pumpCard(tester, FakeApi({'GET /v1/modules': (_) => (200, {'data': modulesJson()})}));

    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Próximamente'), findsOneWidget);
    expect(find.text('Finanzas'), findsNothing);
  });

  testWidgets('renders nothing when the modules cannot be loaded', (tester) async {
    await pumpCard(tester, FakeApi({}));

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Próximamente'), findsNothing);
  });
}
