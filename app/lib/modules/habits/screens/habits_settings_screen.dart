import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/modules/modules_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/switch.dart';
import '../../../ui/toast.dart';
import '../../tasks/ui/form_rows.dart';
import '../../tasks/ui/task_group.dart';
import '../data/habits_models.dart';
import '../data/habits_providers.dart';
import '../ui/habit_break_sheet.dart';

class HabitsSettingsScreen extends ConsumerWidget {
  const HabitsSettingsScreen({super.key});

  Future<void> _save(WidgetRef ref, Map<String, Object?> settings) async {
    try {
      await ref.read(modulesProvider.notifier).updateSettings(habitsModuleId, settings);
    } catch (error) {
      ref
          .read(toastControllerProvider.notifier)
          .error(apiErrorMessage(error, fallback: 'No se han podido guardar los ajustes.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(habitsSettingsProvider);
    final breaks = [
      for (final pause in ref.watch(habitBreaksProvider).value ?? const <HabitBreak>[])
        if (pause.global && (pause.active || pause.upcoming)) pause,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de Hábitos')),
      body: ListView(
        padding: const EdgeInsets.all(CarliSpace.s16),
        children: [
          TaskGroup(
            indent: CarliSpace.s16,
            children: [
              FormRow(
                label: 'Mostrar en Hoy de Tareas',
                chevron: false,
                trailing: CarliSwitch(
                  value: settings.showInTasks,
                  semanticLabel: 'Mostrar en Hoy de Tareas',
                  onChanged: (value) => _save(ref, {'show_in_tasks': value}),
                ),
              ),
              FormRow(
                label: 'Línea en el aviso de las 20:00',
                chevron: false,
                trailing: CarliSwitch(
                  value: settings.digest,
                  semanticLabel: 'Línea en el aviso de las 20:00',
                  onChanged: (value) => _save(ref, {'digest': value}),
                ),
              ),
              const FormRow(label: 'Primer día de la semana', value: 'Lunes', chevron: false),
              const FormRow(label: 'Avisos por hábito', value: 'Próximamente', chevron: false),
            ],
          ),
          const SizedBox(height: CarliSpace.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
            child: Text(
              'Los hábitos nunca entran en Pendientes. A las 20:00 se avisa de los de hoy que faltan y de los semanales en riesgo.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
          ),
          const SizedBox(height: CarliSpace.s24),
          const FormEyebrow('Modo descanso'),
          const SizedBox(height: CarliSpace.s8),
          TaskGroup(
            indent: CarliSpace.s16,
            children: [
              for (final pause in breaks)
                FormRow(label: pause.active ? 'En curso' : 'Programado', value: breakRange(pause), chevron: false),
              FormRow(
                label: breaks.isEmpty ? 'Empezar un descanso' : 'Gestionar descansos',
                onTap: () => showHabitBreakSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
