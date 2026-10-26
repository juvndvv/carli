import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pending/pending_models.dart';
import '../../core/pending/pending_providers.dart';
import '../../core/pending/pending_types.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/button.dart';
import '../../ui/card.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';

class PendingHomeCard extends ConsumerWidget {
  const PendingHomeCard({super.key, required this.onOpen, this.bottomGap = 0});

  final ValueChanged<PendingFilter> onOpen;
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(pendingSummaryProvider).value;
    if (summary == null || summary.total <= 0) return const SizedBox.shrink();
    final colors = context.colors;
    final types = ref.watch(pendingTypeRegistryProvider);
    final card = CarliCard(
      padding: const EdgeInsets.only(top: CarliSpace.s4, bottom: CarliSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Pendientes', style: CarliType.h2.copyWith(color: colors.text)),
                  ),
                ),
                CarliButton(
                  label: 'Revisar',
                  variant: CarliButtonVariant.ghost,
                  size: CarliButtonSize.sm,
                  block: false,
                  onPressed: () => onOpen(PendingFilter.all),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
            child: Text(pendingTotalLabel(summary.total), style: CarliType.small.copyWith(color: colors.text2)),
          ),
          for (final entry in summary.entries)
            CarliListItem(
              key: ValueKey(pendingKey(entry.module, entry.type)),
              title: types.describe(entry.module, entry.type).countLabel(entry.count),
              icon: carliIconNamed(types.describe(entry.module, entry.type).icon),
              trailing: CarliIcon(carliIconNamed('chevron-right'), size: 18, color: colors.text3),
              onTap: () => onOpen(PendingFilter(module: entry.module, type: entry.type)),
            ),
        ],
      ),
    );
    return bottomGap == 0
        ? card
        : Padding(
            padding: EdgeInsets.only(bottom: bottomGap),
            child: card,
          );
  }
}
