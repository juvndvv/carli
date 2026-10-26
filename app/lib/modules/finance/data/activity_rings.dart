import 'models.dart';

/// The three rings of the summary, outer to inner.
///
/// - Disponible: budget left over budget total. Starts full and empties.
/// - Ahorro: period savings over the savings target (a % of income). Fills up.
/// - Ritmo: spending in budgeted categories over what the budget allows by today.
///   Above 100 % means spending faster than planned.
class ActivityRings {
  const ActivityRings({
    required this.budgetedCents,
    required this.remainingCents,
    required this.spentCents,
    required this.plannedByNowCents,
    required this.savingsCents,
    required this.savingsTargetCents,
  });

  factory ActivityRings.of(Dashboard data, {required int savingsTargetPercent, DateTime? now}) {
    final totals = data.budgetTotals;
    final budgeted = totals?.budgetedCents ?? 0;
    final elapsed = periodElapsedFraction(data.period, now ?? DateTime.now());
    return ActivityRings(
      budgetedCents: budgeted,
      remainingCents: totals?.remainingCents ?? 0,
      spentCents: totals?.spentCents ?? 0,
      plannedByNowCents: (budgeted * elapsed).round(),
      savingsCents: data.savingsCents,
      savingsTargetCents: data.incomeCents <= 0 ? 0 : (data.incomeCents * savingsTargetPercent / 100).round(),
    );
  }

  final Cents budgetedCents;
  final Cents remainingCents;
  final Cents spentCents;
  final Cents plannedByNowCents;
  final Cents savingsCents;
  final Cents savingsTargetCents;

  bool get hasBudget => budgetedCents > 0;
  bool get hasSavingsTarget => savingsTargetCents > 0;

  double? get available => hasBudget ? (remainingCents / budgetedCents).clamp(0.0, 1.0) : null;

  double? get savings => hasSavingsTarget ? (savingsCents / savingsTargetCents).clamp(0.0, 2.0) : null;

  double? get pace {
    if (!hasBudget) return null;
    if (plannedByNowCents <= 0) return spentCents > 0 ? 2.0 : 0.0;
    return (spentCents / plannedByNowCents).clamp(0.0, 2.0);
  }

  bool get aheadOfPlan => (pace ?? 0) > 1.0;
}

/// Share of the period gone by, counting today. A past period is 1.
double periodElapsedFraction(Period period, DateTime now) {
  if (!period.isCurrent) return 1;
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(period.startDate.year, period.startDate.month, period.startDate.day);
  final elapsed = today.difference(start).inDays + 1;
  if (elapsed <= 0) return 0;
  final total = elapsed + period.daysRemaining;
  return (elapsed / total).clamp(0.0, 1.0);
}
