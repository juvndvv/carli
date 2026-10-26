import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/badge.dart';
import '../../../ui/card.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/skeleton.dart';
import '../data/finance_format.dart';
import '../data/finance_providers.dart';
import '../data/models.dart';

({CarliBadgeTone tone, String icon, String label})? budgetState(BudgetTotals budget, int threshold) {
  final percent = budget.percentBp;
  if (budget.budgetedCents == 0 || percent == null) return null;
  if (percent > 10000) return (tone: CarliBadgeTone.negative, icon: 'triangle-alert', label: 'Presupuesto superado');
  final label = '${formatPercentRounded(percent)} del presupuesto';
  return percent >= threshold * 100
      ? (tone: CarliBadgeTone.warning, icon: 'triangle-alert', label: label)
      : (tone: CarliBadgeTone.neutral, icon: 'gauge', label: label);
}

class FinanceHomeCard extends ConsumerWidget {
  const FinanceHomeCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final summary = ref.watch(financeSummaryProvider);
    final threshold = ref.watch(financeSettingsProvider).value?.budgetWarningThreshold ?? 80;

    final body = switch (summary) {
      AsyncValue(hasValue: true, :final value) => _Summary(data: value!, threshold: threshold),
      AsyncValue(hasError: true) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s4,
        children: [
          Text('Patrimonio neto', style: CarliType.caption.copyWith(color: colors.text2)),
          Text('No se ha podido cargar el resumen de Finanzas.', style: CarliType.small.copyWith(color: colors.text2)),
        ],
      ),
      _ => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [
          CarliSkeleton(width: 110, height: 12),
          CarliSkeleton(width: 200, height: 36),
          CarliSkeleton(width: 160, height: 14),
        ],
      ),
    };

    return Semantics(
      button: true,
      hint: 'Abrir Finanzas',
      child: CarliCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CarliSpace.s12,
          children: [
            Row(
              spacing: CarliSpace.s8,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                  child: CarliIcon(carliIconNamed('wallet'), size: 18, color: colors.text),
                ),
                Expanded(
                  child: Text('Finanzas', style: CarliType.h2.copyWith(color: colors.text)),
                ),
                CarliIcon(carliIconNamed('chevron-right'), size: 18, color: colors.text3),
              ],
            ),
            body,
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data, required this.threshold});

  final FinanceSummary data;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = budgetState(data.budget, threshold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: CarliSpace.s4,
      children: [
        Text('Patrimonio neto', style: CarliType.caption.copyWith(color: colors.text2)),
        Text(formatMoney(data.netWorthCents), style: CarliType.display.copyWith(color: colors.text)),
        Wrap(
          spacing: CarliSpace.s8,
          runSpacing: CarliSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                style: CarliType.small.copyWith(color: colors.text2),
                children: [
                  TextSpan(text: 'Gastado en ${data.period.shortName}: '),
                  TextSpan(
                    text: formatMoney(data.spentCents),
                    style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                ],
              ),
            ),
            if (state != null) CarliBadge(state.label, tone: state.tone, icon: carliIconNamed(state.icon)),
          ],
        ),
        Text(
          '${data.period.name} · ${daysLeftLabel(data.period.daysRemaining)}',
          style: CarliType.small.copyWith(color: colors.text3),
        ),
      ],
    );
  }
}
