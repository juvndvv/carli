import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/theme/tokens.dart';
import 'package:carli/ui/progress.dart';

import '../support/pump.dart';

void main() {
  test('classifies the ratio against the warning threshold', () {
    expect(progressState(0.5), ProgressState.ok);
    expect(progressState(0.8), ProgressState.warn);
    expect(progressState(1.0), ProgressState.warn);
    expect(progressState(1.01), ProgressState.over);
    expect(progressState(0.6, warnAt: 0.5), ProgressState.warn);
    expect(ratioOf(10, 0), 0);
  });

  testWidgets('keeps the budget bar neutral in every state', (tester) async {
    for (final ratio in [0.3, 0.9, 1.4]) {
      await pumpUi(tester, CarliProgress(ratio: ratio));
      await tester.pumpAndSettle();
      final fill = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)),
      );
      expect((fill.decoration as BoxDecoration).color, CarliColors.light.text);
    }
  });

  testWidgets('uses the strong accent for goals', (tester) async {
    await pumpUi(tester, const CarliProgress(ratio: 0.4, tone: ProgressTone.goal));
    await tester.pumpAndSettle();
    final fill = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)),
    );
    expect((fill.decoration as BoxDecoration).color, CarliColors.light.primaryStrong);
  });

  testWidgets('caps the fill at the full width when exceeded', (tester) async {
    await pumpUi(tester, const CarliProgress(ratio: 1.4));
    await tester.pumpAndSettle();

    expect(tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor, 1);
  });

  testWidgets('paints the fill across the track height and the ratio width', (tester) async {
    await pumpUi(tester, const SizedBox(width: 200, child: CarliProgress(ratio: 0.25)));
    await tester.pumpAndSettle();

    final fill = tester.getSize(
      find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)),
    );
    expect(fill, const Size(50, 8));
  });

  testWidgets('shows the state on the figure', (tester) async {
    Future<TextStyle> figureStyle(int spent) async {
      await pumpUi(tester, CarliProgressFigure(spent: spent, limit: 15000));
      return tester.widget<Text>(find.textContaining('/')).style!;
    }

    final ok = await figureStyle(9000);
    expect(find.text('90 / 150 €'), findsOneWidget);
    expect(ok.color, CarliColors.light.text);
    expect(ok.fontWeight, FontWeight.w400);

    final warn = await figureStyle(14100);
    expect(warn.color, CarliColors.light.warning);
    expect(warn.fontWeight, FontWeight.w600);

    final over = await figureStyle(18250);
    expect(find.text('182,50 / 150 €'), findsOneWidget);
    expect(over.color, CarliColors.light.negative);
  });
}
