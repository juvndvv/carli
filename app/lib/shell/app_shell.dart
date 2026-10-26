import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../modules/finance/screens/transaction_sheet.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon);

  final String label;
  final List<List<dynamic>> icon;
}

const shellDestinations = [
  ShellDestination('Inicio', HugeIconsStrokeRounded.home01),
  ShellDestination('Resumen', HugeIconsStrokeRounded.layoutDashboard),
  ShellDestination('Movimientos', HugeIconsStrokeRounded.list),
  ShellDestination('Presupuestos', HugeIconsStrokeRounded.dashboardSpeed01),
  ShellDestination('Más', HugeIconsStrokeRounded.menu01),
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

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.brandInk : colors.text3;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 3,
          children: [
            HugeIcon(icon: destination.icon, size: 22, color: color, strokeWidth: selected ? 2 : 1.5),
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
