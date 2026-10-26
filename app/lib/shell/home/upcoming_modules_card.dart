import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modules/modules_provider.dart';
import '../../core/theme/tokens.dart';
import '../../ui/badge.dart';
import '../../ui/card.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';

class UpcomingModulesCard extends ConsumerWidget {
  const UpcomingModulesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider).value ?? const [];
    final upcoming = [
      for (final module in modules)
        if (module.comingSoon) module,
    ];
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: CarliSpace.s16),
      child: CarliCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, module) in upcoming.indexed) ...[
              if (index > 0) Divider(indent: 68, color: colors.border),
              CarliListItem(
                title: module.name,
                subtitle: module.description,
                icon: carliIconNamed(module.icon),
                trailing: const CarliBadge('Próximamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
