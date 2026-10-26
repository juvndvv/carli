import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modules/modules_provider.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon_names.dart';
import '../../ui/page.dart';

class ComingSoonModuleScreen extends ConsumerWidget {
  const ComingSoonModuleScreen({super.key, required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final module = ref.watch(modulesProvider).value?.where((module) => module.id == moduleId).firstOrNull;
    return CarliPage(
      title: module?.name ?? 'Próximamente',
      slivers: [
        SliverToBoxAdapter(
          child: CarliEmptyState(
            icon: carliIconNamed(module?.icon),
            title: 'Próximamente',
            message: module?.description ?? 'Este módulo todavía no está disponible.',
          ),
        ),
      ],
    );
  }
}
