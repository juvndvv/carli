import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/app.dart';
import 'package:carli/shell/launch/launch_overlay.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

Finder get wordmark => find.descendant(of: find.byType(LaunchOverlay), matching: find.text('carli'));

void main() {
  testWidgets('plays for a second and a half, then fades out', (tester) async {
    final container = testContainer(FakeApi({}));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
    await tester.pump();
    await tester.pump();

    expect(wordmark, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(wordmark, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(wordmark, findsNothing);
  });

  testWidgets('skips on tap', (tester) async {
    final container = testContainer(FakeApi({}));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(LaunchOverlay));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(wordmark, findsNothing);
  });

  testWidgets('does not animate with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = testContainer(FakeApi({}));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CarliApp()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(wordmark, findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
