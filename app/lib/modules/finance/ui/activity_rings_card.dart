import 'package:flutter/widgets.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/card.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/ring.dart';
import '../data/activity_rings.dart';
import '../data/finance_format.dart';

/// The summary's three rings (Disponible, Ahorro, Ritmo) with their figures beside them.
/// Each ring keeps its own colour; the over-pace state is told in words and icon, not by the ring.
class ActivityRingsCard extends StatelessWidget {
  const ActivityRingsCard({super.key, required this.rings, this.onTap});

  final ActivityRings rings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pace = rings.pace;
    final entries = [
      _RingEntry(
        label: 'Disponible',
        value: rings.hasBudget ? formatMoney(rings.remainingCents) : '—',
        note: rings.hasBudget ? 'de ${formatMoney(rings.budgetedCents)}' : 'Sin presupuestos',
      ),
      _RingEntry(
        label: 'Ahorro',
        value: rings.hasSavingsTarget ? formatMoney(rings.savingsCents) : '—',
        note: rings.hasSavingsTarget
            ? 'objetivo ${formatMoney(rings.savingsTargetCents)}'
            : 'Sin ingresos en este periodo',
      ),
      _RingEntry(
        label: 'Ritmo',
        value: pace == null ? '—' : formatPercentRounded((pace * 10000).round()),
        note: switch (pace) {
          null => 'Sin presupuestos',
          _ when rings.aheadOfPlan => 'Por encima de lo previsto',
          _ => 'Dentro de lo previsto',
        },
        warning: rings.aheadOfPlan,
      ),
    ];

    return CarliCard(
      onTap: onTap,
      child: Row(
        spacing: CarliSpace.s16,
        children: [
          CarliRings(
            size: 136,
            stroke: 15,
            semanticLabel: [for (final entry in entries) '${entry.label}: ${entry.value}, ${entry.note}'].join('. '),
            rings: [
              CarliRingValue(rings.available, colors.rings[0]),
              CarliRingValue(rings.savings, colors.rings[1]),
              CarliRingValue(pace, colors.rings[2]),
            ],
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: CarliSpace.s8,
                children: [
                  for (final (index, entry) in entries.indexed)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.label, style: CarliType.bodyStrong.copyWith(color: colors.ringInk[index])),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.value,
                            style: CarliType.metric.copyWith(fontSize: 22, height: 26 / 22, color: colors.text),
                          ),
                        ),
                        Row(
                          spacing: CarliSpace.s4,
                          children: [
                            if (entry.warning)
                              CarliIcon(
                                carliIconNamed('trending-up'),
                                size: 13,
                                color: colors.negative,
                                strokeWidth: 2,
                              ),
                            Flexible(
                              child: Text(
                                entry.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CarliType.caption.copyWith(
                                  color: entry.warning ? colors.negative : colors.text2,
                                  fontWeight: entry.warning ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingEntry {
  const _RingEntry({required this.label, required this.value, required this.note, this.warning = false});

  final String label;
  final String value;
  final String note;
  final bool warning;
}
