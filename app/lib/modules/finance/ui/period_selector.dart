import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/sheet.dart';
import '../data/finance_format.dart';
import '../data/finance_providers.dart';
import '../data/models.dart';

class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key, required this.selected, required this.onSelected});

  final Period? selected;
  final ValueChanged<Period> onSelected;

  Future<void> _pick(BuildContext context, PeriodsData periods) async {
    final picked = await showCarliSheet<Period>(
      context,
      title: 'Periodo',
      scrollable: true,
      builder: (context) => _PeriodList(periods: periods.all, selectedId: selected?.id),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final periods = ref.watch(periodsProvider).value ?? const PeriodsData([]);
    final current = selected ?? periods.current;
    final older = current == null ? null : periods.olderThan(current);
    final newer = current == null ? null : periods.newerThan(current);
    return Row(
      spacing: CarliSpace.s8,
      children: [
        CarliButton.icon(
          icon: carliIconNamed('chevron-left'),
          semanticLabel: 'Periodo anterior',
          size: CarliButtonSize.sm,
          onPressed: older == null ? null : () => onSelected(older),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Elegir periodo',
            child: Pressable(
              onTap: periods.all.isEmpty ? null : () => _pick(context, periods),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(CarliRadius.control),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: CarliSpace.s4,
                  children: [
                    Flexible(
                      child: Text(
                        current == null ? 'Periodo' : periodButtonLabel(current),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                    ),
                    CarliIcon(carliIconNamed('chevron-down'), size: 14, color: colors.text3),
                  ],
                ),
              ),
            ),
          ),
        ),
        CarliButton.icon(
          icon: carliIconNamed('chevron-right'),
          semanticLabel: 'Periodo siguiente',
          size: CarliButtonSize.sm,
          onPressed: newer == null ? null : () => onSelected(newer),
        ),
      ],
    );
  }
}

class _PeriodList extends StatelessWidget {
  const _PeriodList({required this.periods, required this.selectedId});

  final List<Period> periods;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: CarliSpace.s16),
      itemCount: periods.length,
      separatorBuilder: (_, _) => Divider(indent: CarliSpace.s20, color: colors.border),
      itemBuilder: (context, index) {
        final period = periods[index];
        final selected = period.id == selectedId || (selectedId == null && period.isCurrent);
        return Semantics(
          selected: selected,
          button: true,
          child: Pressable(
            onTap: () => Navigator.pop(context, period),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s20, vertical: CarliSpace.s12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(period.name, style: CarliType.body.copyWith(color: colors.text)),
                        Text(
                          '${period.rangeLabel}${period.isCurrent ? ' · en curso' : ''}',
                          style: CarliType.small.copyWith(color: colors.text3),
                        ),
                      ],
                    ),
                  ),
                  if (selected) CarliIcon(carliIconNamed('check'), size: 20, color: colors.brandInk, strokeWidth: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
