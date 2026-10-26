import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/modules/app_module.dart';
import '../core/modules/modules_provider.dart';
import '../core/router/router.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../core/pending/pending_providers.dart';
import '../modules/finance/screens/transaction_sheet.dart';
import '../ui/icon.dart';
import '../ui/icon_names.dart';
import '../ui/pressable.dart';
import 'pending/pending_badge.dart';

/// Which set of tabs the bar shows: carli's general home lists the modules, a module lists its own screens.
enum ShellContext { home, finance }

ShellContext shellContextFor(String location) =>
    location == Routes.home || _homeChildren.any(location.startsWith) ? ShellContext.home : ShellContext.finance;

const _homeChildren = [Routes.pending, Routes.notifications, Routes.search, Routes.comingSoon];

class ShellTab {
  const ShellTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.comingSoon = false,
    this.showsPending = false,
  });

  final String label;
  final CarliIconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool comingSoon;
  final bool showsPending;
}

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.branch, {this.showsPending = false});

  final String label;
  final CarliIconData icon;

  /// Index of the router branch this tab opens. Branch 0 is Inicio, pinned at the left of every bar.
  final int branch;
  final bool showsPending;
}

const financeDestinations = [
  ShellDestination('Resumen', HugeIconsStrokeRounded.layoutDashboard, 1),
  ShellDestination('Movimientos', HugeIconsStrokeRounded.list, 2),
  ShellDestination('Presupuestos', HugeIconsStrokeRounded.dashboardSpeed01, 3),
  ShellDestination('Más', HugeIconsStrokeRounded.menu01, 4, showsPending: true),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell, required this.location});

  final StatefulNavigationShell navigationShell;
  final String location;

  void _select(int branch) => navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellContext = shellContextFor(location);
    final atHome = shellContext == ShellContext.home;
    final home = ShellTab(
      label: 'Inicio',
      icon: HugeIconsStrokeRounded.home01,
      selected: atHome && !location.startsWith(Routes.comingSoon),
      onTap: () => _select(0),
    );
    final tabs = switch (shellContext) {
      ShellContext.home => _moduleTabs(context, ref.watch(modulesProvider).value),
      ShellContext.finance => [
        for (final destination in financeDestinations)
          ShellTab(
            label: destination.label,
            icon: destination.icon,
            selected: destination.branch == navigationShell.currentIndex,
            onTap: () => _select(destination.branch),
            showsPending: destination.showsPending,
          ),
      ],
    };

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: CarliBottomNav(
        home: home,
        tabs: tabs,
        onAdd: atHome ? null : () => showTransactionSheet(context),
      ),
    );
  }

  /// Modules the user turned off are left out; the ones still to come are listed dimmed and open a teaser.
  List<ShellTab> _moduleTabs(BuildContext context, List<AppModule>? modules) {
    if (modules == null) {
      return [
        ShellTab(
          label: 'Finanzas',
          icon: carliIconNamed('wallet'),
          selected: false,
          onTap: () => context.go(Routes.summary),
        ),
      ];
    }
    return [
      for (final module in modules)
        if (module.comingSoon)
          ShellTab(
            label: module.name,
            icon: carliIconNamed(module.icon),
            selected: location == Routes.comingSoonModule(module.id),
            onTap: () => context.go(Routes.comingSoonModule(module.id)),
            comingSoon: true,
          )
        else if (module.enabled)
          ShellTab(
            label: module.name,
            icon: carliIconNamed(module.icon),
            selected: false,
            onTap: () => context.go(module.route),
          ),
    ];
  }
}

/// Floating tab bar: a translucent capsule with Inicio pinned at the left, the context's tabs scrolling
/// beside it and, inside a module, the round "+" button.
class CarliBottomNav extends StatelessWidget {
  const CarliBottomNav({super.key, required this.home, required this.tabs, this.onAdd});

  final ShellTab home;
  final List<ShellTab> tabs;
  final VoidCallback? onAdd;

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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NavItem(tab: home),
                              Expanded(child: _TabStrip(tabs: tabs)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (onAdd case final onAdd?)
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

/// Horizontally scrolling tabs that fade at the edge with more to see and bring the selected tab into view.
class _TabStrip extends StatefulWidget {
  const _TabStrip({required this.tabs});

  final List<ShellTab> tabs;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  static const _fadeWidth = 24.0;

  final _controller = ScrollController();
  final _keys = <String, GlobalKey>{};
  var _fadeStart = false;
  var _fadeEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFades);
    _afterLayout();
  }

  @override
  void didUpdateWidget(_TabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final labelsChanged = !_sameLabels(oldWidget.tabs, widget.tabs);
    if (labelsChanged && _controller.hasClients) _controller.jumpTo(0);
    if (labelsChanged || _selectedLabel(oldWidget.tabs) != _selectedLabel(widget.tabs)) _afterLayout();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static bool _sameLabels(List<ShellTab> a, List<ShellTab> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i].label == b[i].label].every((same) => same);

  static String? _selectedLabel(List<ShellTab> tabs) => tabs.where((tab) => tab.selected).firstOrNull?.label;

  void _afterLayout() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _updateFades();
    _revealSelected();
  });

  void _updateFades() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) return;
    final position = _controller.position;
    final fadeStart = position.extentBefore > 0.5;
    final fadeEnd = position.extentAfter > 0.5;
    if (fadeStart != _fadeStart || fadeEnd != _fadeEnd) {
      setState(() {
        _fadeStart = fadeStart;
        _fadeEnd = fadeEnd;
      });
    }
  }

  void _revealSelected() {
    final label = _selectedLabel(widget.tabs);
    final tabContext = label == null ? null : _keys[label]?.currentContext;
    final tabBox = tabContext?.findRenderObject() as RenderBox?;
    final stripBox = context.findRenderObject() as RenderBox?;
    if (tabContext == null || tabBox == null || stripBox == null) return;
    final left = tabBox.localToGlobal(Offset.zero, ancestor: stripBox).dx;
    final policy = left < 0
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : left + tabBox.size.width > stripBox.size.width
        ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
        : null;
    if (policy == null) return;
    Scrollable.ensureVisible(tabContext, duration: CarliMotion.enter, curve: Curves.easeOut, alignmentPolicy: policy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fade = (_fadeWidth / constraints.maxWidth).clamp(0.0, 0.5);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              _fadeStart ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              _fadeEnd ? Colors.transparent : Colors.black,
            ],
            stops: [0, fade, 1 - fade, 1],
          ).createShader(bounds),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _updateFades();
              return false;
            },
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth, minHeight: constraints.maxHeight),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final tab in widget.tabs)
                      KeyedSubtree(
                        key: _keys.putIfAbsent(tab.label, GlobalKey.new),
                        child: _NavItem(tab: tab),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({required this.tab});

  final ShellTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = tab.selected;
    final color = selected ? colors.brandInk : colors.text2;
    final pending = tab.showsPending ? ref.watch(pendingTotalProvider) : 0;
    final icon = HugeIcon(icon: tab.icon, size: 22, color: color, strokeWidth: selected ? 2 : 1.5);
    return Semantics(
      button: true,
      selected: selected,
      label: switch (tab) {
        _ when pending > 0 => '${tab.label}, $pending pendientes',
        ShellTab(comingSoon: true) => '${tab.label}, próximamente',
        _ => tab.label,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tab.onTap,
        child: Opacity(
          opacity: tab.comingSoon && !selected ? 0.5 : 1,
          child: AnimatedContainer(
            duration: CarliMotion.enter,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minWidth: 60),
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12),
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
                  tab.label,
                  maxLines: 1,
                  softWrap: false,
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
      ),
    );
  }
}
