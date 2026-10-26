import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/activity_rings.dart';
import 'package:carli/modules/finance/data/models.dart';

Period _period({required DateTime start, required int daysRemaining, bool current = true}) => Period(
  id: 'p',
  startDate: start,
  expectedEndDate: null,
  isCurrent: current,
  name: 'Octubre',
  shortName: 'oct',
  rangeLabel: '',
  daysRemaining: daysRemaining,
);

void main() {
  test('counts today as elapsed and treats a past period as complete', () {
    final period = _period(start: DateTime(2026, 10, 1), daysRemaining: 20);
    expect(periodElapsedFraction(period, DateTime(2026, 10, 10, 18)), 10 / 30);
    expect(
      periodElapsedFraction(
        _period(start: DateTime(2026, 9, 1), daysRemaining: 0, current: false),
        DateTime(2026, 10, 10),
      ),
      1,
    );
  });

  test('disponible empties, ritmo compares with the plan to date and ahorro fills against the target', () {
    const rings = ActivityRings(
      budgetedCents: 120000,
      remainingCents: 30000,
      spentCents: 90000,
      plannedByNowCents: 60000,
      savingsCents: 25000,
      savingsTargetCents: 50000,
    );
    expect(rings.available, 0.25);
    expect(rings.pace, 1.5);
    expect(rings.aheadOfPlan, isTrue);
    expect(rings.savings, 0.5);
  });

  test('leaves the rings empty without budgets or income', () {
    const rings = ActivityRings(
      budgetedCents: 0,
      remainingCents: 0,
      spentCents: 0,
      plannedByNowCents: 0,
      savingsCents: -1000,
      savingsTargetCents: 0,
    );
    expect(rings.available, isNull);
    expect(rings.pace, isNull);
    expect(rings.savings, isNull);
    expect(rings.aheadOfPlan, isFalse);
  });
}
