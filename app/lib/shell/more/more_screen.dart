import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/notifications/notifications_providers.dart';
import '../../core/pending/pending_models.dart';
import '../../core/pending/pending_providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../ui/card.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';
import '../../ui/page.dart';
import '../notifications/unread_dot.dart';
import '../pending/pending_badge.dart';

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
  MoreEntry('Ajustes de finanzas', 'settings', Routes.financeSettings),
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

    final pendingTotal = ref.watch(pendingTotalProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;
    Widget trailingWith(Widget indicator) =>
        Row(mainAxisSize: MainAxisSize.min, spacing: CarliSpace.s8, children: [indicator, chevron()]);

    return CarliPage(
      title: 'Más',
      slivers: [
        SliverList.list(
          children: [
            group('General', [
              CarliListItem(
                title: 'Pendientes',
                subtitle: pendingTotalLabel(pendingTotal),
                icon: carliIconNamed('inbox'),
                trailing: trailingWith(const PendingBadge()),
                onTap: () => context.push(Routes.pending),
              ),
              CarliListItem(
                title: 'Notificaciones',
                icon: carliIconNamed('bell'),
                trailing: unread > 0 ? trailingWith(UnreadDot(semanticLabel: '$unread sin leer')) : chevron(),
                onTap: () => context.push(Routes.notifications),
              ),
              CarliListItem(
                title: 'Buscar',
                icon: carliIconNamed('search'),
                trailing: chevron(),
                onTap: () => context.push(Routes.search),
              ),
            ]),
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
              CarliListItem(
                title: 'Ajustes',
                icon: carliIconNamed('settings'),
                trailing: chevron(),
                onTap: () => context.push(Routes.settings),
              ),
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
