import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/modules/app_module.dart';
import '../core/modules/modules_provider.dart';
import '../core/router/router.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'badge.dart';
import 'icon.dart';
import 'icon_names.dart';
import 'list_item.dart';
import 'pressable.dart';
import 'sheet.dart';

/// Where the switcher can take you: carli's general home or one module.
class ModuleTarget {
  const ModuleTarget({required this.id, required this.name, required this.icon, required this.route, this.subtitle});

  final String id;
  final String name;
  final String icon;
  final String route;
  final String? subtitle;
}

const homeTarget = ModuleTarget(
  id: 'home',
  name: 'Inicio',
  icon: 'house',
  route: Routes.home,
  subtitle: 'Pendientes, avisos y todos tus módulos',
);

const _financeFallback = ModuleTarget(
  id: AppModuleIds.finance,
  name: 'Finanzas',
  icon: 'wallet',
  route: Routes.summary,
);

/// Which target a location belongs to. The "Más" tab lives with Finanzas, the only module with tabs.
String moduleIdForLocation(String path) =>
    path == Routes.home || _homeChildren.any(path.startsWith) ? homeTarget.id : AppModuleIds.finance;

const _homeChildren = [Routes.pending, Routes.notifications, Routes.search];

/// Pill at the top left of every tab: shows the current module and opens the list of modules.
class ModuleSwitcher extends ConsumerWidget {
  const ModuleSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentId = moduleIdForLocation(_locationOf(context));
    final current = currentId == homeTarget.id ? homeTarget : _targetFor(ref.watch(modulesProvider).value, currentId);

    return Semantics(
      button: true,
      label: 'Módulo: ${current.name}. Cambiar de módulo',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => showModuleSheet(context, currentId: currentId),
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: CarliSpace.s8, right: CarliSpace.s8),
          decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.full)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: CarliSpace.s4,
            children: [
              CarliIcon(carliIconNamed(current.icon), size: 16, color: colors.text, strokeWidth: 2),
              Text(current.name, style: CarliType.bodyStrong.copyWith(color: colors.text)),
              CarliIcon(carliIconNamed('chevron-down'), size: 14, color: colors.text2, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page's own location; screens shown outside the router (previews, tests) count as Finanzas.
String _locationOf(BuildContext context) =>
    GoRouter.maybeOf(context) == null ? Routes.summary : GoRouterState.of(context).uri.path;

ModuleTarget _targetFor(List<AppModule>? modules, String id) {
  final module = modules?.where((module) => module.id == id).firstOrNull;
  if (module == null) return id == AppModuleIds.finance ? _financeFallback : homeTarget;
  return ModuleTarget(
    id: module.id,
    name: module.name,
    icon: module.icon,
    route: module.route,
    subtitle: module.description,
  );
}

Future<void> showModuleSheet(BuildContext context, {required String currentId}) => showCarliSheet<void>(
  context,
  title: 'Módulos',
  builder: (sheetContext) => _ModuleList(
    currentId: currentId,
    onSelected: (target) {
      Navigator.of(sheetContext).pop();
      if (target.id != currentId) context.go(target.route);
    },
  ),
);

class _ModuleList extends ConsumerWidget {
  const _ModuleList({required this.currentId, required this.onSelected});

  final String currentId;
  final ValueChanged<ModuleTarget> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final modules = ref.watch(modulesProvider).value;
    final active = [
      homeTarget,
      if (modules == null)
        _financeFallback
      else
        for (final module in modules)
          if (module.available && module.enabled) _targetFor(modules, module.id),
    ];
    final upcoming = [
      for (final module in modules ?? const <AppModule>[])
        if (module.comingSoon) module,
    ];
    final check = CarliIcon(carliIconNamed('check'), size: 20, color: colors.brandInk, strokeWidth: 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s4, 0, CarliSpace.s4, CarliSpace.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final target in active)
            Semantics(
              selected: target.id == currentId,
              child: CarliListItem(
                title: target.name,
                subtitle: target.subtitle,
                icon: carliIconNamed(target.icon),
                trailing: target.id == currentId ? check : null,
                onTap: () => onSelected(target),
              ),
            ),
          for (final module in upcoming)
            Opacity(
              opacity: 0.5,
              child: CarliListItem(
                title: module.name,
                subtitle: module.description,
                icon: carliIconNamed(module.icon),
                trailing: const CarliBadge('Próximamente'),
              ),
            ),
        ],
      ),
    );
  }
}
