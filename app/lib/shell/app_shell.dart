import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../core/pending/pending_providers.dart';
import '../modules/finance/screens/transaction_sheet.dart';
import '../ui/pressable.dart';
import 'pending/pending_badge.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.branch, {this.showsPending = false});

  final String label;
  final List<List<dynamic>> icon;

  /// Index of the router branch this tab opens. Branch 0 (Inicio) has no tab: it opens from the module switcher.
  final int branch;
  final bool showsPending;
}

const shellDestinations = [
  ShellDestination('Resumen', HugeIconsStrokeRounded.layoutDashboard, 1),
  ShellDestination('Movimientos', HugeIconsStrokeRounded.list, 2),
  ShellDestination('Presupuestos', HugeIconsStrokeRounded.dashboardSpeed01, 3),
  ShellDestination('Más', HugeIconsStrokeRounded.menu01, 4, showsPending: true),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int branch) => navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: CarliBottomNav(
        currentBranch: navigationShell.currentIndex,
        onSelected: _select,
        onAdd: () => showTransactionSheet(context),
      ),
    );
  }
}

/// Floating tab bar: a translucent capsule with the tabs and, beside it, the round "+" button.
class CarliBottomNav extends StatelessWidget {
  const CarliBottomNav({super.key, required this.currentBranch, required this.onSelected, required this.onAdd});

  final int currentBranch;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  static const height = 62.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = BoxDecoration(
      color: colors.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(CarliRadius.full),
      border: Border.all(color: colors.text.withValues(alpha: 0.08), width: 0.5),
    );
    final shadow = [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: CarliSpace.s8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, 0),
        child: Row(
          spacing: CarliSpace.s12,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(CarliRadius.full), boxShadow: shadow),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CarliRadius.full),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: DecoratedBox(
                      decoration: glass,
                      child: SizedBox(
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.all(CarliSpace.s4),
                          child: Row(
                            children: [
                              for (final destination in shellDestinations)
                                Expanded(
                                  child: _NavItem(
                                    destination: destination,
                                    selected: destination.branch == currentBranch,
                                    onTap: () => onSelected(destination.branch),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Nuevo movimiento',
              excludeSemantics: true,
              child: Pressable(
                onTap: onAdd,
                child: Container(
                  width: height,
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle, boxShadow: shadow),
                  child: HugeIcon(
                    icon: HugeIconsStrokeRounded.add01,
                    color: colors.onPrimary,
                    size: 28,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final color = selected ? colors.brandInk : colors.text2;
    final pending = destination.showsPending ? ref.watch(pendingTotalProvider) : 0;
    final icon = HugeIcon(icon: destination.icon, size: 22, color: color, strokeWidth: selected ? 2 : 1.5);
    return Semantics(
      button: true,
      selected: selected,
      label: pending > 0 ? '${destination.label}, $pending pendientes' : destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: CarliMotion.enter,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? colors.text.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(CarliRadius.full),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              if (pending > 0)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    icon,
                    Positioned(
                      left: 14,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.warning,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.surface, width: 1.5),
                        ),
                        child: Text(
                          pendingBadgeLabel(pending),
                          style: CarliType.caption.copyWith(
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                icon,
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CarliType.caption.copyWith(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
