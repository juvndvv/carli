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
import 'pending/pending_badge.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, {this.showsPending = false});

  final String label;
  final List<List<dynamic>> icon;
  final bool showsPending;
}

const shellDestinations = [
  ShellDestination('Inicio', HugeIconsStrokeRounded.home01),
  ShellDestination('Resumen', HugeIconsStrokeRounded.layoutDashboard),
  ShellDestination('Movimientos', HugeIconsStrokeRounded.list),
  ShellDestination('Presupuestos', HugeIconsStrokeRounded.dashboardSpeed01),
  ShellDestination('Más', HugeIconsStrokeRounded.menu01, showsPending: true),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo movimiento',
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        highlightElevation: 2,
        shape: const CircleBorder(),
        onPressed: () => showTransactionSheet(context),
        child: HugeIcon(icon: HugeIconsStrokeRounded.add01, color: colors.onPrimary, size: 26, strokeWidth: 2),
      ),
      bottomNavigationBar: CarliBottomNav(currentIndex: navigationShell.currentIndex, onSelected: _select),
    );
  }
}

class CarliBottomNav extends StatelessWidget {
  const CarliBottomNav({super.key, required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (final (index, destination) in shellDestinations.indexed)
                    Expanded(
                      child: _NavItem(
                        destination: destination,
                        selected: index == currentIndex,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
    final color = selected ? colors.brandInk : colors.text3;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 3,
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
    );
  }
}
