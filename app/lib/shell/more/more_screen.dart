import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../ui/card.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';
import '../../ui/page.dart';

class MoreEntry {
  const MoreEntry(this.label, this.icon, this.path);

  final String label;
  final String icon;
  final String path;
}

const financeEntries = [
  MoreEntry('Cuentas', 'landmark', Routes.accounts),
  MoreEntry('Categorías', 'tag', Routes.categories),
  MoreEntry('Recurrentes', 'repeat', Routes.recurring),
  MoreEntry('Objetivos', 'target', Routes.goals),
  MoreEntry('Deudas', 'hand-coins', Routes.debts),
  MoreEntry('Compartidos', 'users', Routes.shared),
  MoreEntry('Ajustes', 'settings', Routes.financeSettings),
];

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    Widget chevron() => CarliIcon(carliIconNamed('chevron-right'), size: 18, color: colors.text3);

    Widget group(String title, List<Widget> items) => CarliSection(
      title: title,
      child: CarliCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index > 0) Divider(indent: 68, color: colors.border),
              item,
            ],
          ],
        ),
      ),
    );

    return CarliPage(
      title: 'Más',
      slivers: [
        SliverList.list(
          children: [
            group('Finanzas', [
              for (final entry in financeEntries)
                CarliListItem(
                  title: entry.label,
                  icon: carliIconNamed(entry.icon),
                  trailing: chevron(),
                  onTap: () => context.push(entry.path),
                ),
            ]),
            group('Cuenta', [
              if (kDebugMode)
                CarliListItem(
                  title: 'Catálogo de componentes',
                  icon: carliIconNamed('palette'),
                  trailing: chevron(),
                  onTap: () => context.push(Routes.catalog),
                ),
              CarliListItem(
                title: 'Cerrar sesión',
                icon: carliIconNamed('log-out'),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ]),
          ],
        ),
      ],
    );
  }
}
