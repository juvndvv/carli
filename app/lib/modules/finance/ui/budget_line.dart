import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/progress.dart';
import '../data/finance_format.dart';
import '../data/models.dart';

class BudgetLine extends StatelessWidget {
  const BudgetLine({super.key, required this.row, this.showProjection = false, this.badge});

  final BudgetRow row;
  final bool showProjection;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final exceeded = row.status == BudgetStatus.exceeded;
    final (figureColor, figureIcon) = switch (row.status) {
      BudgetStatus.ok => (colors.text2, null),
      BudgetStatus.warning => (colors.warning, carliIconNamed('triangle-alert')),
      BudgetStatus.exceeded => (colors.negative, carliIconNamed('circle-alert')),
    };
    final figure = '${formatMoney(row.spentCents)} / ${formatMoney(budgetLimit(row))}';
    final notes = [
      budgetNote(row.status, row.remainingCents),
      if (showProjection && row.projectedStatus != BudgetStatus.ok && row.projectedStatus != row.status)
        'Proyección ${formatMoney(row.projectedCents)}',
      if (row.rolloverInCents != 0)
        '${row.rolloverInCents > 0 ? 'Arrastras' : 'Arrastras un exceso de'} '
            '${formatMoney(row.rolloverInCents, display: MoneyDisplay.absolute)}',
    ];
    final status = switch (row.status) {
      BudgetStatus.ok => 'en margen',
      BudgetStatus.warning => 'cerca del límite',
      BudgetStatus.exceeded => 'excedido',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Semantics(
          label: '${row.category.label}: $figure, $status',
          excludeSemantics: true,
          child: Row(
            spacing: CarliSpace.s8,
            children: [
              Expanded(
                child: Text(
                  row.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CarliType.small.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    spacing: CarliSpace.s4,
                    children: [
                      if (figureIcon != null) CarliIcon(figureIcon, size: 14, color: figureColor, strokeWidth: 2),
                      Text(
                        figure,
                        style: CarliType.money(CarliType.small).copyWith(
                          color: figureColor,
                          fontWeight: exceeded || row.status == BudgetStatus.warning
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        CarliProgress(ratio: budgetBarRatio(row), label: 'Presupuesto de ${row.category.label}'),
        Row(
          spacing: CarliSpace.s8,
          children: [
            Expanded(
              child: Text(notes.join(' · '), style: CarliType.caption.copyWith(color: colors.text2)),
            ),
            ?badge,
          ],
        ),
      ],
    );
  }
}
