import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/app_module.dart';
import '../../core/modules/modules_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/async_view.dart';
import '../../ui/badge.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';
import '../../ui/page.dart';
import '../../ui/skeleton.dart';
import '../../ui/switch.dart';
import '../../ui/toast.dart';
import 'settings_screen.dart';

class ModuleSettingsScreen extends ConsumerStatefulWidget {
  const ModuleSettingsScreen({super.key});

  @override
  ConsumerState<ModuleSettingsScreen> createState() => _ModuleSettingsScreenState();
}

class _ModuleSettingsScreenState extends ConsumerState<ModuleSettingsScreen> {
  String? _pending;

  Future<void> _toggle(AppModule module, bool enabled) async {
    setState(() => _pending = module.id);
    try {
      await ref.read(modulesProvider.notifier).setEnabled(module.id, enabled);
    } catch (_) {
      ref.read(toastControllerProvider.notifier).error('No se ha podido cambiar el módulo');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final modules = ref.watch(modulesProvider);
    return CarliPage(
      title: 'Módulos',
      onRefresh: () async {
        ref.invalidate(modulesProvider);
        await ref.read(modulesProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, 0),
              child: Text(
                'Un módulo desactivado desaparece de la navegación. Tus datos se conservan.',
                style: CarliType.small.copyWith(color: colors.text2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(modules.hasValue ? 0 : CarliSpace.s16),
              child: AsyncView(
                value: modules,
                errorTitle: 'No se han podido cargar los módulos',
                onRetry: () => ref.invalidate(modulesProvider),
                loading: const Column(
                  spacing: CarliSpace.s12,
                  children: [CarliSkeleton(height: 56), CarliSkeleton(height: 56), CarliSkeleton(height: 56)],
                ),
                data: (items) => _ModuleList(modules: items, pending: _pending, onToggle: _toggle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.modules, required this.pending, required this.onToggle});

  final List<AppModule> modules;
  final String? pending;
  final void Function(AppModule module, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final available = [
      for (final module in modules)
        if (module.available) module,
    ];
    final upcoming = [
      for (final module in modules)
        if (module.comingSoon) module,
    ];
    final withSettings = [
      for (final module in available)
        if (module.enabled && moduleSettingsLocationOf(module.id) != null) module,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (available.isNotEmpty)
          SettingsGroup(
            title: 'Disponibles',
            children: [
              for (final module in available)
                CarliListItem(
                  title: module.name,
                  subtitle: module.description,
                  icon: carliIconNamed(module.icon),
                  trailing: CarliSwitch(
                    value: module.enabled,
                    semanticLabel: 'Activar ${module.name}',
                    onChanged: pending == module.id ? null : (value) => onToggle(module, value),
                  ),
                ),
            ],
          ),
        if (withSettings.isNotEmpty)
          SettingsGroup(
            title: 'Ajustes de módulos',
            children: [
              for (final module in withSettings)
                CarliListItem(
                  title: 'Ajustes de ${module.name}',
                  icon: carliIconNamed('settings'),
                  trailing: const SettingsChevron(),
                  onTap: () => context.push(moduleSettingsLocationOf(module.id)!),
                ),
            ],
          ),
        if (upcoming.isNotEmpty)
          SettingsGroup(
            title: 'Próximamente',
            children: [
              for (final module in upcoming)
                CarliListItem(
                  title: module.name,
                  subtitle: module.description,
                  icon: carliIconNamed(module.icon),
                  trailing: const CarliBadge('Próximamente'),
                ),
            ],
          ),
      ],
    );
  }
}
