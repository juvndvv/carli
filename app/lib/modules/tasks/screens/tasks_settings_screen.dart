import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/modules/modules_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/select.dart';
import '../../../ui/switch.dart';
import '../../../ui/toast.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/form_rows.dart';
import '../ui/pickers.dart';
import '../ui/task_group.dart';

class TasksSettingsScreen extends ConsumerWidget {
  const TasksSettingsScreen({super.key});

  Future<void> _save(WidgetRef ref, Map<String, Object?> settings) async {
    try {
      await ref.read(modulesProvider.notifier).updateSettings(tasksModuleId, settings);
    } catch (error) {
      ref
          .read(toastControllerProvider.notifier)
          .error(apiErrorMessage(error, fallback: 'No se han podido guardar los ajustes.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(tasksSettingsProvider);
    final lists = ref.watch(taskListsProvider).value ?? const <TaskList>[];
    final defaultList =
        lists.where((list) => list.id == settings.defaultListId).firstOrNull ??
        lists.where((list) => list.isDefault).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de Tareas')),
      body: ListView(
        padding: const EdgeInsets.all(CarliSpace.s16),
        children: [
          TaskGroup(
            indent: CarliSpace.s16,
            children: [
              FormRow(
                label: 'Lista por defecto',
                value: defaultList?.name ?? 'Bandeja',
                onTap: () async {
                  final picked = await pickTaskList(context, lists: lists, current: defaultList?.id);
                  if (picked != null) await _save(ref, {'default_list_id': picked});
                },
              ),
              FormRow(
                label: 'Si no la completas',
                value: settings.defaultPolicy.label,
                onTap: () async {
                  final picked = await pickCarliOption<TemplatePolicy>(
                    context,
                    title: 'Política por defecto',
                    value: settings.defaultPolicy,
                    options: [
                      for (final policy in TemplatePolicy.values)
                        CarliOption(policy, policy.label, subtitle: policy.hint),
                    ],
                  );
                  if (picked != null) await _save(ref, {'default_policy': picked.$1.api});
                },
              ),
              FormRow(
                label: 'Mostrar hechas en Hoy',
                chevron: false,
                trailing: CarliSwitch(
                  value: settings.showDoneInToday,
                  semanticLabel: 'Mostrar hechas en Hoy',
                  onChanged: (value) => _save(ref, {'show_done_in_today': value}),
                ),
              ),
              const FormRow(label: 'Avisos a la hora de la tarea', value: 'Próximamente', chevron: false),
            ],
          ),
          const SizedBox(height: CarliSpace.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
            child: Text(
              'Las tareas vencidas aparecen en Pendientes y las de hoy entran en el resumen de las 20:00.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
          ),
        ],
      ),
    );
  }
}
